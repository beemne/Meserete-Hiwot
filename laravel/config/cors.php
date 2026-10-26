<?php

// Same policy as the Node.js API: CORS headers only for the origins listed in CORS_ORIGINS
// (none by default — the mobile app does not need CORS). No credentials.
$origins = array_values(array_filter(array_map('trim', explode(',', (string) env('CORS_ORIGINS', '')))));

return [
    'paths' => $origins ? ['*'] : [],
    'allowed_methods' => ['*'],
    'allowed_origins' => $origins,
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
