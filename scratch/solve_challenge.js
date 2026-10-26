const https = require('https');

function get(url) {
  return new Promise((resolve, reject) => {
    https.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5'
      }
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
    }).on('error', reject);
  });
}

function post(url, body, cookie) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const postData = new URLSearchParams(body).toString();
    const req = https.request({
      hostname: u.hostname,
      port: 443,
      path: u.pathname + u.search,
      method: 'POST',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData),
        'Cookie': cookie || '',
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

async function run() {
  console.log("Fetching challenge page...");
  const res1 = await get('https://app.hersolan.pro/');
  console.log("Status:", res1.status, "Cookies:", res1.headers['set-cookie']);
  
  // Let's inspect the body for the script
  const scriptMatch = res1.body.match(/<script>([\s\S]*?)<\/script>/);
  if (!scriptMatch) {
    console.log("No script tag found!");
    return;
  }
  const script = scriptMatch[1];
  console.log("Script snippet:", script.slice(0, 200));

  // In the script:
  // e = +((...)...)
  // L = +((...)...)
  // o = '/z...'
  // id, ts
  const oMatch = script.match(/o='(\/[a-f0-9]+)'/);
  const o = oMatch ? oMatch[1] : null;
  console.log("Endpoint o:", o);

  // We can use a minimal sandbox or eval to run the math part
  // Notice the script has: e=+((...)), L=+((...))
  const eMatch = script.match(/e=\+\(([\s\S]*?)\),\s*d=/);
  const lMatch = script.match(/L=\+\(([\s\S]*?)\),\s*i=/);
  const idMatch = script.match(/r\['value'\]='([a-f0-9]+)'\+C\(a0F\.Y\)\+C\(0xce\)\+'([a-f0-9]+)'/);
  const tsMatch = script.match(/N\['value'\]='(\d+)'/);

  console.log("Matches:", { hasE: !!eMatch, hasL: !!lMatch, o, hasId: !!idMatch, ts: tsMatch ? tsMatch[1] : null });
}

run().catch(console.error);
