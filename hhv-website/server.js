'use strict';

const http = require('http');

const PORT = Number(process.env.PORT || 3001);
const PUBLIC_URL = process.env.PUBLIC_URL || 'https://helpfulhirschventures.com';

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', service: 'hhv-website', placeholder: true }));
    return;
  }

  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Helpful Hirsch Ventures</title></head>
<body>
  <h1>Helpful Hirsch Ventures</h1>
  <p>Infrastructure is live. Replace this placeholder with the production Next.js app.</p>
  <p><a href="${PUBLIC_URL}/health">Health check</a></p>
</body>
</html>`);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`HHV placeholder listening on :${PORT}`);
});
