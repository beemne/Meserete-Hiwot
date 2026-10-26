<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        if (\Illuminate\Support\Facades\DB::connection()->getDriverName() === 'sqlite') {
            try {
                \Illuminate\Support\Facades\DB::connection()->getPdo()->sqliteCreateFunction('FIND_IN_SET', function ($val, $list) {
                    if ($val === null || $list === null) return 0;
                    $items = explode(',', (string) $list);
                    $idx = array_search((string) $val, $items, true);
                    return $idx === false ? 0 : $idx + 1;
                });
            } catch (\Throwable) {
            }
        }
    }
}
