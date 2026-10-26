<?php

namespace App\Console\Commands;

use App\Mz\Services\Sinksar;
use App\Mz\Support\Dates;
use DateTimeImmutable;
use Illuminate\Console\Command;
use Throwable;

class RefreshSinksar extends Command
{
    protected $signature = 'sinksar:refresh {--notify : Also dispatch daily Sinksar notifications}';
    protected $description = 'Refresh Ethiopian Orthodox daily Sinksar data and commemorations from source';

    public function handle(): int
    {
        $this->info('Starting Daily Sinksar Refresh...');

        try {
            // 1. Fetch & cache today
            $today = Sinksar::forToday();
            $this->info("Today: {$today['formatted_full']} (Gregorian: {$today['gregorian_date']})");
            $this->line("Featured: {$today['featured_title']}");
            $this->line("Annual: " . count($today['annual_feasts']) . " | Monthly: " . count($today['monthly_feasts']));

            // 2. Pre-fetch tomorrow so midnight transition is seamless
            $tomorrowDt = (new DateTimeImmutable('now', Dates::tz()))->modify('+1 day');
            $tomorrow = Sinksar::forDate($tomorrowDt->format('Y-m-d'));
            $this->info("Tomorrow pre-cached: {$tomorrow['formatted_full']} ({$tomorrow['gregorian_date']})");

            // 3. Dispatch notifications if requested
            if ($this->option('notify')) {
                $notifRes = Sinksar::sendDailyNotification();
                $this->info("Notification Dispatch: " . json_encode($notifRes, JSON_UNESCAPED_UNICODE));
            }

            $this->info('Sinksar refresh completed successfully.');
            return Command::SUCCESS;
        } catch (Throwable $e) {
            $this->error("Sinksar refresh failed: {$e->getMessage()}");
            return Command::FAILURE;
        }
    }
}
