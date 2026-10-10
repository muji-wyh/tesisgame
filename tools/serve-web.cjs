const fs = require('node:fs');
const path = require('node:path');
const httpServer = require('http-server');

function createWebServer(directory) {
  const root = path.resolve(directory);
  const server = httpServer.createServer({
    root, cache: -1, brotli: true, showDir: 'false',
    before: [(request, response) => {
      const pathname = new URL(request.url, 'http://localhost').pathname;
      if (!/^\/game-[a-f0-9]{16}\.pck\.br$/.test(pathname) ||
          !['GET', 'HEAD'].includes(request.method)) return response.emit('next');
      const filename = path.join(root, pathname.slice(1));
      fs.stat(filename, (error, stat) => {
        if (error || !stat.isFile()) {
          response.writeHead(404, { 'Content-Type': 'text/plain', 'Cache-Control': 'no-store' });
          return response.end('Game pack not found.');
        }
        // http-server negotiates sidecars but does not encode explicit .br URLs.
        // Match Azure: stream the compressed file once; Fetch decodes its body.
        response.writeHead(200, {
          'Content-Type': 'application/octet-stream',
          'Content-Encoding': 'br',
          'Content-Length': stat.size,
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Vary': 'Accept-Encoding',
          'Accept-Ranges': 'none'
        });
        if (request.method === 'HEAD') return response.end();
        const stream = fs.createReadStream(filename);
        stream.on('error', error => response.response.destroy(error));
        response.response.on('close', () => stream.destroy());
        stream.pipe(response);
      });
    }]
  });
  return server.server;
}

module.exports = { createWebServer };

if (require.main === module) {
  const args = process.argv.slice(2);
  const port = args.length === 0 ? 41773 : args.length === 2 && args[0] === '--port' ? Number(args[1]) : NaN;
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    console.error('Usage: node tools/serve-web.cjs [--port 41773]');
    process.exitCode = 1;
  } else {
    const server = createWebServer(path.resolve(__dirname, '../build/web'));
    server.on('error', error => { console.error(error.message); process.exitCode = 1; });
    server.listen(port, '127.0.0.1', () => console.log(`Grow with Pip: http://127.0.0.1:${port}/`));
  }
}
