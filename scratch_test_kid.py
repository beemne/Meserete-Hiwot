import base64
import hashlib
import hmac

def get_kid(app_key_str):
    if app_key_str.startswith('base64:'):
        ikm = base64.b64decode(app_key_str[7:])
    else:
        ikm = app_key_str.encode('utf-8')
    
    # HKDF-SHA256 (extract & expand) with info='mz-seal-v1'
    # In Seal.php: hash_hkdf('sha256', (string) $ikm, 32, 'mz-seal-v1');
    import hmac
    # HKDF extract with empty salt (32 zeros):
    prk = hmac.new(b'\x00' * 32, ikm, hashlib.sha256).digest()
    # HKDF expand:
    info = b'mz-seal-v1'
    t1 = hmac.new(prk, info + b'\x01', hashlib.sha256).digest()[:32]
    # kid: first 4 bytes of sha256(t1)
    kid = hashlib.sha256(t1).digest()[:4]
    return kid.hex()

print("mhs APP_KEY kid:", get_kid("base64:Q+LSM0tVbukjw3CZwCaCkog87gYztiJXaNUJ0pyL3FY="))
print("app APP_KEY kid:", get_kid("base64:z8B6Cybu5XqYTYb8OeFAqL3partPoHqpPxxa2F8nqoI="))
