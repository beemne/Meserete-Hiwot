import requests
import json

base_url = 'https://app.hersolan.pro/api/v1'

login_resp = requests.post(f'{base_url}/auth/login', json={
    'identifier': '0911000000',
    'secret': '123456'
})
print('LOGIN STATUS:', login_resp.status_code)
token = login_resp.json().get('token')
headers = {'Authorization': f'Bearer {token}'}

for qid in [16, 6, 4]:
    print(f'\n--- TESTING QUIZ {qid} ---')
    r_detail = requests.get(f'{base_url}/edu/quizzes/{qid}', headers=headers)
    print(f'GET /edu/quizzes/{qid} -> {r_detail.status_code}')
    if r_detail.status_code != 200:
        print('DETAIL ERROR:', r_detail.text)
    else:
        print('DETAIL KEYS:', list(r_detail.json().keys()))

    r_results = requests.get(f'{base_url}/edu/quizzes/{qid}/results', headers=headers)
    print(f'GET /edu/quizzes/{qid}/results -> {r_results.status_code}')
    if r_results.status_code != 200:
        print('RESULTS ERROR:', r_results.text)
    else:
        print('RESULTS STUDENTS COUNT:', len(r_results.json().get('students', [])))
