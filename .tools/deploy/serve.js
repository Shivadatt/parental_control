const http = require('http');
const fs = require('fs');
const path = require('path');
const root = __dirname;
http.createServer((req, res) => {
  const name = path.basename(decodeURIComponent(req.url.split('?')[0]));
  const file = path.join(root, name);
  fs.readFile(file, (err, data) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    if (err) { res.statusCode = 404; return res.end('not found'); }
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.end(data);
  });
}).listen(8765, '127.0.0.1', () => console.log('listening 8765'));
