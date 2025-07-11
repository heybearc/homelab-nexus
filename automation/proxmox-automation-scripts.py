#!/usr/bin/env python3
"""
Proxmox Community Scripts Automation Framework
Integrates tteck/Proxmox community scripts for automated LXC deployment and management
"""

import requests
import subprocess
import json
import os
import sys
from typing import Dict, List, Optional
import argparse

class ProxmoxCommunityScripts:
    def __init__(self, proxmox_host: str = "10.92.0.5", proxmox_user: str = "root", proxmox_password: str = "Cl0udy!!(@"):
        self.proxmox_host = proxmox_host
        self.proxmox_user = proxmox_user
        self.proxmox_password = proxmox_password
        self.github_api_base = "https://api.github.com/repos/tteck/Proxmox"
        self.github_raw_base = "https://raw.githubusercontent.com/tteck/Proxmox/main"
        
    def get_available_scripts(self) -> Dict[str, List[str]]:
        """Get list of available community scripts from GitHub"""
        try:
            # Get container scripts
            ct_response = requests.get(f"{self.github_api_base}/contents/ct")
            ct_scripts = [item['name'] for item in ct_response.json() if item['name'].endswith('.sh')]
            
            # Get install scripts
            install_response = requests.get(f"{self.github_api_base}/contents/install")
            install_scripts = [item['name'] for item in install_response.json() if item['name'].endswith('.sh')]
            
            return {
                "container_scripts": ct_scripts,
                "install_scripts": install_scripts
            }
        except Exception as e:
            print(f"Error fetching scripts: {e}")
            return {"container_scripts": [], "install_scripts": []}
    
    def download_script(self, script_path: str, local_path: str = None) -> str:
        """Download a specific script from the repository"""
        if local_path is None:
            local_path = f"/tmp/{os.path.basename(script_path)}"
            
        try:
            url = f"{self.github_raw_base}/{script_path}"
            response = requests.get(url)
            response.raise_for_status()
            
            with open(local_path, 'w') as f:
                f.write(response.text)
            
            os.chmod(local_path, 0o755)
            return local_path
        except Exception as e:
            print(f"Error downloading script {script_path}: {e}")
            return None
    
    def execute_remote_script(self, script_url: str, container_id: int = None) -> bool:
        """Execute a community script on the Proxmox host"""
        try:
            if container_id:
                # Execute script for specific container
                cmd = f"sshpass -p '{self.proxmox_password}' ssh -o StrictHostKeyChecking=no {self.proxmox_user}@{self.proxmox_host} 'bash <(curl -s {script_url}) -c {container_id}'"
            else:
                # Execute script on host
                cmd = f"sshpass -p '{self.proxmox_password}' ssh -o StrictHostKeyChecking=no {self.proxmox_user}@{self.proxmox_host} 'bash <(curl -s {script_url})'"
            
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                print(f"Script executed successfully: {script_url}")
                print(f"Output: {result.stdout}")
                return True
            else:
                print(f"Script execution failed: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"Error executing script: {e}")
            return False
    
    def deploy_service(self, service_name: str, **kwargs) -> Optional[int]:
        """Deploy a service using community scripts"""
        service_scripts = {
            "adguard": "ct/adguard.sh",
            "bazarr": "ct/bazarr.sh", 
            "homarr": "ct/homarr.sh",
            "jellyfin": "ct/jellyfin.sh",
            "nginx-proxy-manager": "ct/nginxproxymanager.sh",
            "overseerr": "ct/overseerr.sh",
            "prowlarr": "ct/prowlarr.sh",
            "radarr": "ct/radarr.sh",
            "readarr": "ct/readarr.sh",
            "sabnzbd": "ct/sabnzbd.sh",
            "sonarr": "ct/sonarr.sh",
            "tautulli": "ct/tautulli.sh",
            "transmission": "ct/transmission.sh",
            "netbox": "ct/netbox.sh"
        }
        
        if service_name.lower() not in service_scripts:
            print(f"Service {service_name} not found in available scripts")
            return None
            
        script_path = service_scripts[service_name.lower()]
        script_url = f"{self.github_raw_base}/{script_path}"
        
        print(f"Deploying {service_name} using {script_url}")
        
        if self.execute_remote_script(script_url):
            # Get the container ID of the newly created container
            return self.get_latest_container_id()
        
        return None
    
    def get_latest_container_id(self) -> Optional[int]:
        """Get the ID of the most recently created container"""
        try:
            cmd = f"sshpass -p '{self.proxmox_password}' ssh -o StrictHostKeyChecking=no {self.proxmox_user}@{self.proxmox_host} 'pct list | tail -1 | awk \"{{print \\$1}}\"'"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                container_id = int(result.stdout.strip())
                return container_id
        except Exception as e:
            print(f"Error getting latest container ID: {e}")
        
        return None
    
    def update_container_config(self, container_id: int, config_updates: Dict[str, str]) -> bool:
        """Update container configuration (NFS mounts, resources, etc.)"""
        try:
            for key, value in config_updates.items():
                cmd = f"sshpass -p '{self.proxmox_password}' ssh -o StrictHostKeyChecking=no {self.proxmox_user}@{self.proxmox_host} 'pct set {container_id} --{key} \"{value}\"'"
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
                
                if result.returncode != 0:
                    print(f"Failed to update {key}: {result.stderr}")
                    return False
                    
            return True
        except Exception as e:
            print(f"Error updating container config: {e}")
            return False
    
    def add_nfs_mount(self, container_id: int, mount_point: str = "/mnt/data") -> bool:
        """Add NFS mount to container"""
        config_updates = {
            "mp0": f"/mnt/pve/nfs-data,mp={mount_point}"
        }
        return self.update_container_config(container_id, config_updates)
    
    def enable_tun_device(self, container_id: int) -> bool:
        """Enable TUN device for VPN support"""
        try:
            # Stop container first
            cmd = f"sshpass -p '{self.proxmox_password}' ssh -o StrictHostKeyChecking=no {self.proxmox_user}@{self.proxmox_host} 'pct stop {container_id}'"
            subprocess.run(cmd, shell=True)
            
            # Add TUN device configuration
            config_file = f"/etc/pve/lxc/{container_id}.conf"
            tun_config = """
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net dev/net none bind,create=dir
"""
            
            cmd = f"sshpass -p '{self.proxmox_password}' ssh -o StrictHostKeyChecking=no {self.proxmox_user}@{self.proxmox_host} 'echo \"{tun_config}\" >> {config_file}'"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            # Start container
            cmd = f"sshpass -p '{self.proxmox_password}' ssh -o StrictHostKeyChecking=no {self.proxmox_user}@{self.proxmox_host} 'pct start {container_id}'"
            subprocess.run(cmd, shell=True)
            
            return result.returncode == 0
        except Exception as e:
            print(f"Error enabling TUN device: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description="Proxmox Community Scripts Automation")
    parser.add_argument("--list", action="store_true", help="List available scripts")
    parser.add_argument("--deploy", type=str, help="Deploy a service")
    parser.add_argument("--container-id", type=int, help="Container ID for operations")
    parser.add_argument("--add-nfs", action="store_true", help="Add NFS mount to container")
    parser.add_argument("--enable-tun", action="store_true", help="Enable TUN device for container")
    
    args = parser.parse_args()
    
    pcs = ProxmoxCommunityScripts()
    
    if args.list:
        scripts = pcs.get_available_scripts()
        print("Available Container Scripts:")
        for script in scripts["container_scripts"]:
            print(f"  - {script}")
        print("\nAvailable Install Scripts:")
        for script in scripts["install_scripts"]:
            print(f"  - {script}")
    
    elif args.deploy:
        container_id = pcs.deploy_service(args.deploy)
        if container_id:
            print(f"Service {args.deploy} deployed with container ID: {container_id}")
        else:
            print(f"Failed to deploy {args.deploy}")
    
    elif args.add_nfs and args.container_id:
        if pcs.add_nfs_mount(args.container_id):
            print(f"NFS mount added to container {args.container_id}")
        else:
            print(f"Failed to add NFS mount to container {args.container_id}")
    
    elif args.enable_tun and args.container_id:
        if pcs.enable_tun_device(args.container_id):
            print(f"TUN device enabled for container {args.container_id}")
        else:
            print(f"Failed to enable TUN device for container {args.container_id}")
    
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
