const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs').promises;
const path = require('path');

const app = express();
const port = 3999;
const dataDir = './data';
const API_KEY = '74585769-5708-40c8-9db0-e4f5fd8c570d'; // 设置你的API密钥

// 中间件
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// 自定义头中间件
const customHeaderMiddleware = (req, res, next) => {
  // 设置自定义头
  res.setHeader('X-Custom-Header', '74585769-5708-40c8-9db0-e4f5fd8c570d');
  // 允许所有跨域请求
  res.setHeader('Access-Control-Allow-Origin', '*');
  // 其他自定义头...
  next();
};

// API密钥验证中间件
const apiKeyMiddleware = (req, res, next) => {
  const providedKey = req.headers['x-api-key'];
  if (providedKey && providedKey === API_KEY) {
    next();
  } else {
    res.status(403).send('API key is missing or invalid');
  }
};

// 确保数据目录存在
async function ensureDataDirExists() {
  try {
    await fs.mkdir(dataDir, { recursive: true });
  } catch (err) {
    console.error('Error creating data directory:', err);
  }
}

ensureDataDirExists();

// 使用自定义头中间件
app.use(customHeaderMiddleware);

// 读取文件
app.get('/read/:filename', apiKeyMiddleware, async (req, res) => {
  const filename = req.params.filename;
  const filePath = path.join(dataDir, filename);

  try {
    const data = await fs.readFile(filePath, 'utf8');
    res.send(data);
  } catch (err) {
    if (err.code === 'ENOENT') {
      res.status(404).send('File not found');
    } else {
      res.status(500).send('Error reading file');
    }
  }
});

// 写入文件
app.post('/write/:filename', apiKeyMiddleware, async (req, res) => {
  const filename = req.params.filename;
  const filePath = path.join(dataDir, filename);
  const content = req.body.content;

  try {
    await fs.writeFile(filePath, content);
    res.status(201).send('File written successfully');
  } catch (err) {
    res.status(500).send('Error writing file');
  }
});

// 启动服务器
app.listen(port, () => {
  console.log(`File API server running at http://localhost:${port}`);
});