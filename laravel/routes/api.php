<?php

// /api/v1 — one file per area in routes/api/, mirroring the Node.js backend's src/routes/.

foreach (glob(__DIR__ . '/api/*.php') as $file) {
    require $file;
}
