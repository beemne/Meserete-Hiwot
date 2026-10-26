<?php

namespace App\Mz\Db;

use DateTimeZone;

/**
 * A DATE column. The Node API (mysql2, timezone Z) sent these as UTC midnight
 * ("2026-10-01T00:00:00.000Z"); the JSON form is kept identical. As a string it is "2026-10-01".
 */
class DbDate extends UtcDateTime
{
    public function __toString(): string
    {
        return $this->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d');
    }
}
