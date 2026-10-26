const https = require('https');

function get(url, headers = {}) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers }, res => {
      let d = ''; res.on('data', c => d += c);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: d }));
    }).on('error', reject);
  });
}

function decodeJsFuckNumber(expr) {
  const groupRegex = /\(([^)]+)\)/g;
  let digits = '';
  let match;
  while ((match = groupRegex.exec(expr)) !== null) {
    const inner = match[1];
    // count occurrences of !+[] or !![]
    const terms = (inner.match(/!\+\[\]|!!\[\]/g) || []).length;
    digits += terms;
  }
  return parseInt(digits, 10);
}

async function solvePureRegex() {
  const ua = 'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';
  const page = await get('https://app.hersolan.pro/', { 'User-Agent': ua });
  
  if (!page.body.includes('One moment, please...')) {
    console.log("No challenge on page! Status:", page.status);
    return;
  }
  
  const scripts = page.body.match(/<script>([\s\S]*?)<\/script>/g);
  const s = scripts[scripts.length - 1];
  
  const eExprMatch = s.match(/e=\+\(([\s\S]*?)\),\s*d=/);
  const lExprMatch = s.match(/L=\+\(([\s\S]*?)\),\s*i=/);
  const oMatch = s.match(/o='(\/[a-f0-9]+)'/);
  const tsMatch = s.match(/N\['value'\]='(\d+)'/);
  
  const e = decodeJsFuckNumber(eExprMatch[1]);
  const l = decodeJsFuckNumber(lExprMatch[1]);
  const wsidchk = e + l;
  const o = oMatch[1];
  const ts = tsMatch[1];
  
  // Extract all 10-char hex chunks from the array a0d()
  // Array definition: var j=['...', '60b54a2be4', 'd49030b349', ...]
  const arrMatch = s.match(/var j=\[([\s\S]*?)\];/);
  const hexChunks = (arrMatch[1].match(/'([a-f0-9]{10})'/g) || []).map(x => x.replace(/'/g, ''));
  // The id is '7fa3b767c4' + chunk1 + chunk2 + 'c7'
  const valueMatch = s.match(/r\['value'\]='([a-f0-9]+)'\+[\s\S]*?\+'([a-f0-9]+)'/);
  const prefix = valueMatch ? valueMatch[1] : '7fa3b767c4';
  const suffix = valueMatch ? valueMatch[2] : 'c7';
  
  // Notice in the script: r['value']='7fa3b767c4'+C(a0F.Y)+C(0xce)+'c7'
  // In the array, chunk 0 is 60b54a2be4, chunk 1 is d49030b349 (or vice-versa)
  // Let's test with hexChunks[0] + hexChunks[1]
  const id = prefix + hexChunks[0] + hexChunks[1] + suffix;
  
  console.log({ e, l, wsidchk, o, ts, id });
  
  const target = `https://app.hersolan.pro${o}?wsidchk=${wsidchk}&pdata=https%253A%252F%252Fapp.hersolan.pro&id=${id}&ts=${ts}&cttl=0`;
  console.log("Submitting to:", target);
  
  const res = await get(target, { 'User-Agent': ua });
  console.log("Response:", res.status, res.headers['set-cookie']);
  
  if (res.headers['set-cookie']) {
    const cookie = res.headers['set-cookie'][0].split(';')[0];
    console.log("SUCCESS! Got cookie:", cookie);
    
    // Now verify API call with this cookie!
    const apiRes = await get('https://app.hersolan.pro/api/v1/edu/me/dashboard', {
      'User-Agent': ua,
      'Accept': 'application/json',
      'Cookie': cookie
    });
    console.log("API Response with Cookie:", apiRes.status, apiRes.body.slice(0, 150));
  }
}

solvePureRegex().catch(console.error);
