import subprocess
import time
import urllib.request
import json
import asyncio
import websockets
import base64

routes = ['/login', '/guidance', '/programs', '/settings']

async def run_tests():
    chrome = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
    proc = subprocess.Popen([
        chrome,
        '--headless=new',
        '--remote-debugging-port=9229',
        '--disable-gpu',
        '--ignore-certificate-errors',
        '--window-size=1280,800',
        'https://app.hersolan.pro/'
    ])
    await asyncio.sleep(2)
    
    try:
        with urllib.request.urlopen('http://localhost:9229/json') as r:
            tabs = json.loads(r.read())
            page_tab = [t for t in tabs if t.get('type') == 'page'][0]
            ws_url = page_tab['webSocketDebuggerUrl']
            
        async with websockets.connect(ws_url) as ws:
            await ws.send(json.dumps({'id': 1, 'method': 'Log.enable'}))
            await ws.send(json.dumps({'id': 2, 'method': 'Console.enable'}))
            await ws.send(json.dumps({'id': 3, 'method': 'Runtime.enable'}))
            
            for idx, route in enumerate(routes):
                url = f'https://app.hersolan.pro/#{route}'
                print(f'Navigating to {url}...')
                await ws.send(json.dumps({'id': 10 + idx, 'method': 'Page.navigate', 'params': {'url': url}}))
                await asyncio.sleep(4)
                
                # Check for errors
                errors = []
                while True:
                    try:
                        msg = await asyncio.wait_for(ws.recv(), timeout=0.5)
                        m = json.loads(msg)
                        if m.get('method') in ['Log.entryAdded', 'Runtime.exceptionThrown']:
                            errors.append(m)
                    except asyncio.TimeoutError:
                        break
                        
                print(f'  Route {route} errors: {len(errors)}')
                
                # Take screenshot
                await ws.send(json.dumps({'id': 50 + idx, 'method': 'Page.captureScreenshot'}))
                res = await ws.recv()
                data = json.loads(res)['result']['data']
                clean_name = route.replace('/', '_').strip('_')
                fn = f'page_{clean_name}.png'
                with open(fn, 'wb') as f:
                    f.write(base64.b64decode(data))
                print(f'  Saved screenshot: {fn}')
    finally:
        proc.terminate()

if __name__ == '__main__':
    asyncio.run(run_tests())
