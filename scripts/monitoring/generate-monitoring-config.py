#!/usr/bin/env python3
"""Generate Prometheus scrape configs, watchdog instances map, and uptime hints from apps-registry.yaml."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML required: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

REGISTRY = Path(os.environ.get("REGISTRY", str(Path(__file__).resolve().parent.parent.parent / "monitoring" / "apps-registry.yaml")))


def load_registry() -> dict:
    return yaml.safe_load(REGISTRY.read_text())


def ct_label(ctid: int) -> str:
    return f"ct{ctid}"


def is_scraped(app: dict) -> bool:
    return app.get("state", "active") == "active"


def node_target(inst: dict, app: dict, defaults: dict) -> dict:
    port = inst.get("port", defaults.get("node_exporter_port", 9100))
    host = "localhost" if inst.get("local") else inst["ip"]
    labels = {
        "instance": inst["instance"],
        "container": ct_label(inst["ctid"]),
        "app": app["id"],
        "tier": app.get("tier", "infrastructure"),
        "monitor": defaults.get("monitor_label", "true"),
    }
    return {"targets": [f"{host}:{port}"], "labels": labels}


def generate_scrape_configs(registry: dict) -> list[dict]:
    defaults = registry.get("defaults", {})
    jobs: list[dict] = []

    # Group node_exporter targets by app id
    for app in registry.get("apps", []):
        if not is_scraped(app):
            continue
        instances = app.get("instances") or []
        if not instances:
            continue
        targets = [node_target(i, app, defaults) for i in instances]
        jobs.append(
            {
                "job_name": f"node_{app['id'].replace('-', '_')}",
                "static_configs": targets,
            }
        )

        metrics = app.get("app_metrics")
        if metrics and isinstance(metrics, dict):
            port = metrics.get("port", 3000)
            path = metrics.get("path", "/metrics")
            static = []
            for inst in instances:
                static.append(
                    {
                        "targets": [f"{inst['ip']}:{port}"],
                        "labels": {
                            "instance": inst["instance"],
                            "container": ct_label(inst["ctid"]),
                            "app": app["id"],
                            "monitor": "false",
                        },
                    }
                )
            jobs.append(
                {
                    "job_name": f"{app['id'].replace('-', '_')}_metrics",
                    "metrics_path": path,
                    "static_configs": static,
                }
            )

        for exp in app.get("postgres_exporter") or []:
            jobs.append(
                {
                    "job_name": f"postgres_exporter_{exp['instance'].replace('-', '_')}",
                    "static_configs": [
                        {
                            "targets": [f"{exp['ip']}:{exp['port']}"],
                            "labels": {
                                "instance": exp["instance"],
                                "container": ct_label(exp["ctid"]),
                                "role": exp.get("role", "primary"),
                                "monitor": "false",
                            },
                        }
                    ],
                }
            )

        for exp in app.get("haproxy_exporter") or []:
            jobs.append(
                {
                    "job_name": f"haproxy_stats_{exp['instance'].replace('-', '_')}",
                    "static_configs": [
                        {
                            "targets": [f"{exp['ip']}:{exp['port']}"],
                            "labels": {
                                "instance": exp["instance"],
                                "container": ct_label(exp["ctid"]),
                                "monitor": "false",
                            },
                        }
                    ],
                }
            )

        for bot in app.get("bot_metrics") or []:
            for port in bot.get("ports", []):
                jobs.append(
                    {
                        "job_name": f"bot_{bot['instance']}_{port}",
                        "static_configs": [
                            {
                                "targets": [f"{bot['ip']}:{port}"],
                                "labels": {
                                    "instance": bot["instance"],
                                    "container": ct_label(bot["ctid"]),
                                    "monitor": "false",
                                },
                            }
                        ],
                    }
                )

        for redis in app.get("redis_exporter") or []:
            jobs.append(
                {
                    "job_name": "redis_exporter",
                    "static_configs": [
                        {
                            "targets": [f"{redis['ip']}:{redis['port']}"],
                            "labels": {
                                "instance": redis["instance"],
                                "container": ct_label(redis["ctid"]),
                                "monitor": "false",
                            },
                        }
                    ],
                }
            )

        for job in app.get("custom_jobs") or []:
            cfg = {
                "job_name": job["job_name"],
                "static_configs": [
                    {
                        "targets": job["targets"],
                        "labels": job.get("labels", {}),
                    }
                ],
            }
            if job.get("scrape_timeout"):
                cfg["scrape_timeout"] = job["scrape_timeout"]
            jobs.append(cfg)

    return jobs


def generate_watchdog_map(registry: dict) -> dict:
    instances: dict[str, int] = {}
    archived: list[str] = []
    failover: list[str] = []

    for app in registry.get("apps", []):
        state = app.get("state", "active")
        for inst in app.get("instances") or []:
            name = inst["instance"]
            if state == "archived":
                archived.append(name)
            elif state == "active":
                instances[name] = inst["ctid"]
        if app.get("watchdog_failover") and state == "active":
            for inst in app.get("instances") or []:
                failover.append(inst["instance"])

    return {
        "instances": instances,
        "archived": sorted(set(archived)),
        "failover_instances": sorted(set(failover)),
    }


def generate_prometheus_yml(registry: dict) -> str:
    defaults = registry.get("defaults", {})
    scrape_jobs = generate_scrape_configs(registry)

    header = """global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: homelab
    env: production

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - "/etc/prometheus/rules/windows-alerts.yml"
  - /etc/prometheus/rules/*.yml

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']

"""
    lines = [header]
    for job in scrape_jobs:
        lines.append(f"  - job_name: {job['job_name']}\n")
        if job.get("metrics_path"):
            lines.append(f"    metrics_path: {job['metrics_path']}\n")
        if job.get("scrape_timeout"):
            lines.append(f"    scrape_timeout: {job['scrape_timeout']}\n")
        lines.append("    static_configs:\n")
        for sc in job["static_configs"]:
            lines.append(f"      - targets: {json.dumps(sc['targets'])}\n")
            lines.append("        labels:\n")
            for k, v in sc["labels"].items():
                lines.append(f"          {k}: '{v}'\n")
    return "".join(lines)


def dump_yaml_scrape(jobs: list[dict]) -> str:
    return yaml.dump({"scrape_configs": jobs}, default_flow_style=False, sort_keys=False)


def main() -> None:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} {{prometheus|watchdog|uptime}}", file=sys.stderr)
        sys.exit(1)

    registry = load_registry()
    cmd = sys.argv[1]

    if cmd == "prometheus":
        print(generate_prometheus_yml(registry))
    elif cmd == "watchdog":
        print(json.dumps(generate_watchdog_map(registry), indent=2))
    elif cmd == "uptime":
        checks = []
        for app in registry.get("apps", []):
            if app.get("state", "active") == "archived":
                continue
            for u in app.get("uptime") or []:
                if u.get("active") is False:
                    continue
                checks.append({"app": app["id"], **u})
        print(yaml.dump({"uptime_checks": checks}, default_flow_style=False))
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
