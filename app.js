const port = process.env.PORT || 3000;
const FILE_PATH = process.env.FILE_PATH || '/tmp';
const UUID = process.env.UUID;
const express = require("express");
const app = express();
const fs = require("fs");
const path = require("path");
const { spawn } = require('child_process');
const OPENSERVER = process.env.OPENSERVER || '1';

app.get("/", function (req, res) {
  res.status(200).send("hello world");
});

app.get(`/${UUID}`, (req, res) => {
  let subfilePath = path.join(FILE_PATH, "log.txt");
  fs.readFile(subfilePath, (err, data) => {
    if (err) {
      return res.status(500).send('Error reading file');
    }
    res.type("txt").send(data);
  });
});

if (OPENSERVER === '1') {
  // do nothing
} else if (OPENSERVER === '0') {
  const { createProxyMiddleware } = require("http-proxy-middleware");
  app.use(
    "/",
    createProxyMiddleware({
      changeOrigin: true,
      onProxyReq: function onProxyReq(proxyReq, req, res) {},
      pathRewrite: {
        "^/": "/"
      },
      target: "http://127.0.0.1:8080/",
      ws: true
    })
  );
}

// run
const startScriptPath = `/app/start.sh`;
const childProcess = spawn(startScriptPath, [], {
  detached: false,
  stdio: 'inherit',
});

app.listen(port, () => console.log(`server is listening on port ${port}!`));
