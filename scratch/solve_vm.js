const https = require('https');

function get(url) {
  return new Promise((resolve, reject) => {
    https.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9'
      }
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
    }).on('error', reject);
  });
}

function post(url, params) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const postData = new URLSearchParams(params).toString();
    const req = https.request({
      hostname: u.hostname,
      port: 443,
      path: u.pathname + u.search,
      method: 'POST',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData),
        'Origin': 'https://app.hersolan.pro',
        'Referer': 'https://app.hersolan.pro/'
      }
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function solve() {
  const page = await get('https://app.hersolan.pro/');
  if (!page.body.includes('One moment, please...')) {
    console.log("Already bypassed! Status:", page.status);
    return;
  }
  
  // Extract the second script tag
  const scripts = page.body.match(/<script>([\s\S]*?)<\/script>/g);
  const mainScript = scripts[scripts.length - 1].replace(/<\/?script>/g, '');
  
  function PluginArray() {}
  function Plugin() {}
  function MimeTypeArray() {}
  function MimeType() {}

  // Mock window & document
  let submittedForm = null;
  const mockWindow = {
    navigator: {
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
      appVersion: '5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      languages: ['en-US', 'en'],
      language: 'en-US',
      plugins: [{ '0': {}, length: 1 }],
      mimeTypes: [{ '0': {}, length: 1 }]
    },
    outerWidth: 1920,
    outerHeight: 1080,
    addEventListener: (ev, fn) => fn(),
    attachEvent: (ev, fn) => fn()
  };
  mockWindow.navigator.plugins.__proto__ = PluginArray.prototype;
  mockWindow.navigator.plugins[0].__proto__ = Plugin.prototype;
  mockWindow.navigator.mimeTypes.__proto__ = MimeTypeArray.prototype;
  mockWindow.navigator.mimeTypes[0].__proto__ = MimeType.prototype;
  
  // Let's create an evaluation environment
  const elements = {};
  function createElement(tag) {
    const el = { tag, children: [], attrs: {} };
    el.appendChild = function(child) {
      el.children.push(child);
    };
    if (tag === 'form') {
      el.submit = function() {
        submittedForm = el;
      };
    }
    return el;
  }
  
  const mockDoc = {
    createElement: createElement,
    getElementById: (id) => ({ appendChild: (c) => {} }),
    addEventListener: (ev, fn) => fn()
  };
  mockWindow.document = mockDoc;
  
  // In the script, setTimeout is used with 1000ms delay. We can override setTimeout to run immediately.
  const vm = require('vm');
  const context = {
    window: mockWindow,
    document: mockDoc,
    setTimeout: (fn) => fn(),
    URLSearchParams: URLSearchParams,
    XMLHttpRequest: function() {
      this.open = () => {};
      this.send = () => {};
    },
    PluginArray: function() {},
    Plugin: function() {},
    MimeTypeArray: function() {},
    MimeType: function() {},
    console: console
  };
  context.PluginArray.prototype = {};
  context.Plugin.prototype = {};
  context.MimeTypeArray.prototype = {};
  context.MimeType.prototype = {};
  mockWindow.navigator.plugins.__proto__ = context.PluginArray.prototype;
  mockWindow.navigator.plugins[0].__proto__ = context.Plugin.prototype;
  mockWindow.navigator.mimeTypes.__proto__ = context.MimeTypeArray.prototype;
  mockWindow.navigator.mimeTypes[0].__proto__ = context.MimeType.prototype;

  vm.createContext(context);
  try {
    vm.runInContext(mainScript, context);
  } catch (e) {
    console.error("VM Run error:", e);
  }
  
  console.log("Submitted Form:", submittedForm ? {
    action: submittedForm.action,
    method: submittedForm.method,
    children: submittedForm.children.map(c => ({ name: c.name, value: c.value }))
  } : "None");

  if (submittedForm) {
    const params = new URLSearchParams();
    for (const c of submittedForm.children) {
      if (c.name) params.append(c.name, c.value);
    }
    const targetUrl = 'https://app.hersolan.pro' + submittedForm.action + '?' + params.toString();
    console.log("Submitting GET to:", targetUrl);
    const getRes = await get(targetUrl);
    console.log("Response Status:", getRes.status);
    console.log("Response Headers:", getRes.headers);
    console.log("Response Body (first 300):", getRes.body.slice(0, 300));
  }
}

solve().catch(console.error);
