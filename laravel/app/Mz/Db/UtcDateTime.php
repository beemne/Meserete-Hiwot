<?php

namespace App\Mz\Db;

use DateTimeImmutable;
use DateTimeZone;
use JsonSerializable;

/**
 * A DATETIME / TIMESTAMP value read from MySQL (stored in UTC).
 * JSON form matches the Node.js API exactly: "2026-10-01T07:30:00.000Z".
 * As a string (queries, comparisons with SQL text) it is "2026-10-01 07:30:00".
 */
class UtcDateTime extends DateTimeImmutable implements JsonSerializable
{
    public static function fromDb(string $value): static
    {
        return new static($value, new DateTimeZone('UTC'));
    }

    public function jsonSerialize(): string
    {
        return $this->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d\TH:i:s.v\Z');
    }

    public function __toString(): string
    {
        return $this->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s');
    }

    /** Milliseconds since the epoch (JavaScript getTime()). */
    public function ms(): int
    {
        return (int) $this->format('Uv');
    }
}
