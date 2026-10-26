<?php

namespace App\Providers;

use App\Mz\Db\MzConnection;
use App\Mz\Jobs\Jobs;
use App\Mz\Support\Z;
use Illuminate\Database\Connection;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // DATE / DATETIME columns come back typed (JSON like the Node.js API).
        Connection::resolverFor('mysql', fn ($pdo, $database, $prefix, $config) => new MzConnection($pdo, $database, $prefix, $config));
    }

    public function boot(): void
    {
        Z::init();
        date_default_timezone_set('UTC');
        // The services are a port of JavaScript, where a missing property / key reads as undefined.
        // Warnings (undefined property / array key) therefore do not abort the request; real errors do.
        error_reporting(E_ALL & ~E_WARNING & ~E_NOTICE & ~E_DEPRECATED & ~E_USER_DEPRECATED);
        // Reminders / dispatch / maintenance run request-driven after responses (no cron job).
        if (! $this->app->runningInConsole()) {
            $this->app->terminating(function () {
                try {
                    Jobs::tick();
                } catch (\Throwable $e) {
                    report($e);
                }
            });
        }
    }
}
