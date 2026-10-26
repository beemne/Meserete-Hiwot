<?php

namespace App\Mz\Support;

use App\Mz\Db\UtcDateTime;
use Closure;
use DateTimeZone;

/**
 * A small port of the zod subset the Node.js backend used, so request validation and the error
 * codes it returns stay identical ({field, code, message}; code = the custom message when it is an
 * UPPER_CASE code, otherwise zod's issue code upper-cased: INVALID_TYPE, TOO_SMALL, …).
 *
 *   $body = Z::parse(Z::object(['name' => Z::string()->trim()->min(2, 'TOO_SHORT')]), $input);
 */
final class Z
{
    /** Marks an absent value (JavaScript undefined). */
    public static ?object $UNDEF = null;
    /** Returned by a failed parse step. */
    public static ?object $FAIL = null;

    public static function init(): void
    {
        self::$UNDEF ??= new class {};
        self::$FAIL ??= new class {};
    }

    public static function string(array $o = []): ZString { return new ZString($o); }
    public static function number(array $o = []): ZNumber { return new ZNumber($o); }
    public static function coerceNumber(array $o = []): ZNumber { return (new ZNumber($o))->coerce(); }
    public static function boolean(array $o = []): ZBoolean { return new ZBoolean($o); }
    public static function coerceDate(array $o = []): ZDate { return new ZDate($o); }
    public static function enum(array $values, array $o = []): ZEnum { return new ZEnum($values, $o); }
    public static function literal(mixed $v): ZLiteral { return new ZLiteral($v); }
    public static function array(ZType $item): ZArray { return new ZArray($item); }
    public static function object(array $shape): ZObject { return new ZObject($shape); }
    public static function union(array $options): ZUnion { return new ZUnion($options); }
    public static function record(ZType $value, ?ZType $key = null): ZRecord { return new ZRecord($value, $key); }
    public static function any(): ZAny { return new ZAny(); }
    public static function null(): ZNull { return new ZNull(); }

    /** Parse or throw a 422 VALIDATION_ERROR. Absent keys are dropped from objects. */
    public static function parse(ZType $schema, mixed $value): mixed
    {
        self::init();
        $issues = [];
        $out = $schema->run($value === null && $schema instanceof ZObject ? [] : $value, [], $issues);
        if ($issues || $out === self::$FAIL) {
            throw ApiError::validation(array_map(fn ($i) => self::toError($i), $issues ?: [['path' => [], 'code' => 'custom', 'message' => 'INVALID']]));
        }
        return $out === self::$UNDEF ? null : $out;
    }

    /** Parse without throwing: [ok, value, errors]. */
    public static function safeParse(ZType $schema, mixed $value): array
    {
        try {
            return [true, self::parse($schema, $value), []];
        } catch (ApiError $e) {
            return [false, null, $e->errors];
        }
    }

    public static function toError(array $issue): array
    {
        $msg = $issue['message'];
        return [
            'field' => $issue['path'] ? implode('.', $issue['path']) : null,
            'code' => preg_match('/^[A-Z_]+$/', $msg) ? $msg : strtoupper($issue['code']),
            'message' => $msg,
        ];
    }

    public static function typeOf(mixed $v): string
    {
        return match (true) {
            $v === null => 'null',
            is_bool($v) => 'boolean',
            is_int($v), is_float($v) => (is_float($v) && is_nan($v)) ? 'nan' : 'number',
            is_string($v) => 'string',
            is_array($v) => array_is_list($v) && $v !== [] ? 'array' : 'object',
            default => 'object',
        };
    }

    /** JavaScript Number(v). */
    public static function jsNumber(mixed $v): float|int
    {
        if (is_int($v) || is_float($v)) return $v;
        if (is_bool($v)) return $v ? 1 : 0;
        if ($v === null) return 0;
        if (is_string($v)) {
            $t = trim($v);
            if ($t === '') return 0;
            if (preg_match('/^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/', $t)) {
                $f = (float) $t;
                return (floor($f) == $f && abs($f) < PHP_INT_MAX) ? (int) $f : $f;
            }
            if (preg_match('/^0x[0-9a-f]+$/i', $t)) return hexdec($t);
            return NAN;
        }
        return NAN;
    }
}

/** Issue collector passed to transforms (zod's ctx.addIssue). */
final class ZCtx
{
    public function __construct(private array &$issues, private array $path) {}

    public function addIssue(string $message, string $code = 'custom', array $path = []): object
    {
        $this->issues[] = ['path' => array_merge($this->path, $path), 'code' => $code, 'message' => $message];
        return Z::$FAIL;
    }
}

abstract class ZType
{
    protected bool $optional = false;
    protected bool $nullable = false;
    protected mixed $default = null;
    protected bool $hasDefault = false;
    protected bool $hasCatch = false;
    protected mixed $catchValue = null;
    /** @var array<array{0:string,1:Closure,2?:string,3?:array}> refine / transform, in chain order */
    protected array $effects = [];
    protected ?ZType $pipe = null;
    protected ?string $requiredError = null;
    protected ?string $invalidTypeError = null;

    public function __construct(array $o = [])
    {
        Z::init();
        $this->requiredError = $o['required_error'] ?? null;
        $this->invalidTypeError = $o['invalid_type_error'] ?? null;
    }

    public function optional(): static { $c = clone $this; $c->optional = true; return $c; }
    public function nullable(): static { $c = clone $this; $c->nullable = true; return $c; }
    public function nullish(): static { return $this->optional()->nullable(); }
    public function default(mixed $v): static { $c = clone $this; $c->hasDefault = true; $c->default = $v; return $c; }
    public function catch(mixed $v): static { $c = clone $this; $c->hasCatch = true; $c->catchValue = $v; return $c; }
    private function wrapped(): bool { return $this->optional || $this->nullable || $this->hasDefault || $this->pipe !== null || $this->hasCatch; }
    public function refine(Closure $fn, string|array $message = 'Invalid input'): ZType
    {
        $m = is_array($message) ? $message : ['message' => $message];
        $e = ['refine', $fn, $m['message'] ?? 'Invalid input', $m['path'] ?? []];
        if ($this->wrapped()) return new ZWrap($this, $e);
        $c = clone $this;
        $c->effects[] = $e;
        return $c;
    }
    /** fn($value, ZCtx $ctx): returns the new value (or $ctx->addIssue(...) to fail). After optional() the value may be Z::. */
    public function transform(Closure $fn): ZType
    {
        if ($this->wrapped()) return new ZWrap($this, ['transform', $fn]);
        $c = clone $this;
        $c->effects[] = ['transform', $fn];
        return $c;
    }
    public function pipe(ZType $next): static { $c = clone $this; $c->pipe = $next; return $c; }

    public function isOptional(): bool { return $this->optional || $this->hasDefault; }

    /** As zod .partial(): ZodOptional(ZodDefault(x)) leaves an absent key absent. */
    public function asPartial(): static { $c = clone $this; $c->optional = true; $c->hasDefault = false; return $c; }

    abstract protected function check(mixed $value, array $path, array &$issues): mixed;

    abstract protected function typeName(): string;

    public function run(mixed $value, array $path, array &$issues): mixed
    {
        $start = count($issues);
        $out = $this->runInner($value, $path, $issues);
        if ($this->hasCatch && ($out === Z::$FAIL || count($issues) > $start)) {
            array_splice($issues, $start);
            return $this->catchValue;
        }
        return $out;
    }

    private function runInner(mixed $value, array $path, array &$issues): mixed
    {
        if ($value === Z::$UNDEF) {
            if ($this->hasDefault) {
                $value = $this->default instanceof Closure ? ($this->default)() : $this->default;
            } elseif ($this->optional) {
                return Z::$UNDEF;
            } else {
                $issues[] = ['path' => $path, 'code' => 'invalid_type', 'message' => $this->requiredError ?? 'Required'];
                return Z::$FAIL;
            }
        }
        if ($value === null && $this->nullable) {
            return null;
        }
        $start = count($issues);
        $v = $this->check($value, $path, $issues);
        if ($v === Z::$FAIL || count($issues) > $start) {
            return Z::$FAIL;
        }
        foreach ($this->effects as $e) {
            if ($e[0] === 'refine') {
                if (! ($e[1])($v)) {
                    $issues[] = ['path' => array_merge($path, $e[3]), 'code' => 'custom', 'message' => $e[2]];
                    return Z::$FAIL;
                }
            } else {
                $ctx = new ZCtx($issues, $path);
                $v = ($e[1])($v, $ctx);
                if ($v === Z::$FAIL || count($issues) > $start) {
                    return Z::$FAIL;
                }
            }
        }
        if ($this->pipe) {
            return $this->pipe->run($v, $path, $issues);
        }
        return $v;
    }

    protected function typeIssue(mixed $value, array $path, array &$issues): object
    {
        $issues[] = ['path' => $path, 'code' => 'invalid_type', 'message' => $this->invalidTypeError ?? sprintf('Expected %s, received %s', $this->typeName(), Z::typeOf($value))];
        return Z::$FAIL;
    }
}

final class ZString extends ZType
{
    private array $checks = [];

    protected function typeName(): string { return 'string'; }

    private function add(array $c): static { $x = clone $this; $x->checks[] = $c; return $x; }
    public function trim(): static { return $this->add(['trim']); }
    public function toLowerCase(): static { return $this->add(['lower']); }
    public function toUpperCase(): static { return $this->add(['upper']); }
    public function min(int $n, ?string $m = null): static { return $this->add(['min', $n, $m]); }
    public function max(int $n, ?string $m = null): static { return $this->add(['max', $n, $m]); }
    public function length(int $n, ?string $m = null): static { return $this->add(['len', $n, $m]); }
    public function nonempty(?string $m = null): static { return $this->min(1, $m); }
    public function regex(string $re, ?string $m = null): static { return $this->add(['regex', $re, $m]); }
    public function email(?string $m = null): static { return $this->add(['email', null, $m]); }
    public function url(?string $m = null): static { return $this->add(['url', null, $m]); }
    public function uuid(?string $m = null): static { return $this->add(['uuid', null, $m]); }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        if (! is_string($value)) {
            return $this->typeIssue($value, $path, $issues);
        }
        $v = $value;
        foreach ($this->checks as $c) {
            $len = mb_strlen($v);
            switch ($c[0]) {
                case 'trim': $v = preg_replace('/^[\s\x{FEFF}\x{A0}]+|[\s\x{FEFF}\x{A0}]+$/u', '', $v); break;
                case 'lower': $v = mb_strtolower($v); break;
                case 'upper': $v = mb_strtoupper($v); break;
                case 'min': if ($len < $c[1]) $issues[] = ['path' => $path, 'code' => 'too_small', 'message' => $c[2] ?? "String must contain at least {$c[1]} character(s)"]; break;
                case 'max': if ($len > $c[1]) $issues[] = ['path' => $path, 'code' => 'too_big', 'message' => $c[2] ?? "String must contain at most {$c[1]} character(s)"]; break;
                case 'len': if ($len !== $c[1]) $issues[] = ['path' => $path, 'code' => $len < $c[1] ? 'too_small' : 'too_big', 'message' => $c[2] ?? "String must contain exactly {$c[1]} character(s)"]; break;
                case 'regex': if (! preg_match($c[1], $v)) $issues[] = ['path' => $path, 'code' => 'invalid_string', 'message' => $c[2] ?? 'Invalid']; break;
                case 'email':
                    if (! preg_match("/^(?!\\.)(?!.*\\.\\.)([A-Z0-9_'+\\-\\.]*)[A-Z0-9_+-]@([A-Z0-9][A-Z0-9\\-]*\\.)+[A-Z]{2,}$/i", $v)) {
                        $issues[] = ['path' => $path, 'code' => 'invalid_string', 'message' => $c[2] ?? 'Invalid email'];
                    }
                    break;
                case 'url':
                    $p = parse_url($v);
                    if ($p === false || empty($p['scheme']) || (empty($p['host']) && ! in_array($p['scheme'], ['mailto', 'file'], true))) {
                        $issues[] = ['path' => $path, 'code' => 'invalid_string', 'message' => $c[2] ?? 'Invalid url'];
                    }
                    break;
                case 'uuid':
                    if (! preg_match('/^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$/', $v)) {
                        $issues[] = ['path' => $path, 'code' => 'invalid_string', 'message' => $c[2] ?? 'Invalid uuid'];
                    }
                    break;
            }
        }
        return $v;
    }
}

final class ZNumber extends ZType
{
    private bool $coerce = false;
    private array $checks = [];

    protected function typeName(): string { return 'number'; }

    public function coerce(): static { $c = clone $this; $c->coerce = true; return $c; }
    private function add(array $c): static { $x = clone $this; $x->checks[] = $c; return $x; }
    public function int(?string $m = null): static { return $this->add(['int', null, $m]); }
    public function positive(?string $m = null): static { return $this->add(['gt', 0, $m]); }
    public function nonnegative(?string $m = null): static { return $this->add(['gte', 0, $m]); }
    public function min(int|float $n, ?string $m = null): static { return $this->add(['gte', $n, $m]); }
    public function max(int|float $n, ?string $m = null): static { return $this->add(['lte', $n, $m]); }
    public function gt(int|float $n, ?string $m = null): static { return $this->add(['gt', $n, $m]); }
    public function lt(int|float $n, ?string $m = null): static { return $this->add(['lt', $n, $m]); }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        $v = $this->coerce ? Z::jsNumber($value) : $value;
        if (! (is_int($v) || is_float($v)) || is_bool($value) && ! $this->coerce || (is_float($v) && is_nan($v))) {
            return $this->typeIssue($this->coerce ? $v : $value, $path, $issues);
        }
        if (is_float($v) && floor($v) == $v && abs($v) < 9007199254740992) {
            $v = (int) $v;
        }
        foreach ($this->checks as [$k, $n, $m]) {
            $bad = match ($k) {
                'int' => ! is_int($v),
                'gt' => ! ($v > $n),
                'gte' => ! ($v >= $n),
                'lt' => ! ($v < $n),
                'lte' => ! ($v <= $n),
            };
            if ($bad) {
                $code = match ($k) { 'int' => 'invalid_type', 'gt', 'gte' => 'too_small', default => 'too_big' };
                $def = match ($k) {
                    'int' => 'Expected integer, received float',
                    'gt' => "Number must be greater than $n",
                    'gte' => "Number must be greater than or equal to $n",
                    'lt' => "Number must be less than $n",
                    'lte' => "Number must be less than or equal to $n",
                };
                $issues[] = ['path' => $path, 'code' => $code, 'message' => $m ?? $def];
            }
        }
        return $v;
    }
}

final class ZBoolean extends ZType
{
    protected function typeName(): string { return 'boolean'; }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        return is_bool($value) ? $value : $this->typeIssue($value, $path, $issues);
    }
}

/** z.coerce.date(): anything JavaScript's new Date() accepts → UtcDateTime (second precision kept). */
final class ZDate extends ZType
{
    protected function typeName(): string { return 'date'; }

    public static function toDate(mixed $value): ?UtcDateTime
    {
        if ($value instanceof \DateTimeInterface) {
            return UtcDateTime::createFromInterface($value)->setTimezone(new DateTimeZone('UTC'));
        }
        if (is_int($value) || is_float($value)) {
            $sec = intdiv((int) $value, 1000);
            $ms = ((int) $value) % 1000;
            return UtcDateTime::createFromFormat('U.u', sprintf('%d.%06d', $sec, $ms * 1000), new DateTimeZone('UTC')) ?: null;
        }
        if (! is_string($value) || trim($value) === '') {
            return null;
        }
        $s = trim($value);
        // Date-only ISO strings are UTC midnight in JavaScript; other strings without an offset are
        // read as UTC (the server's time zone).
        if (! preg_match('/^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?)?(Z|[+-]\d{2}:?\d{2})?$/i', $s)) {
            if (! preg_match('/^[A-Za-z]{3},? /', $s)) {
                return null;
            }
        }
        try {
            $d = new UtcDateTime($s, new DateTimeZone('UTC'));
        } catch (\Throwable) {
            return null;
        }
        $errors = UtcDateTime::getLastErrors();
        if ($errors && ($errors['warning_count'] || $errors['error_count'])) {
            return null;
        }
        return $d->setTimezone(new DateTimeZone('UTC'));
    }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        $d = self::toDate($value);
        if (! $d) {
            $issues[] = ['path' => $path, 'code' => 'invalid_date', 'message' => $this->invalidTypeError ?? 'Invalid date'];
            return Z::$FAIL;
        }
        return $d;
    }
}

final class ZEnum extends ZType
{
    public function __construct(private array $values, array $o = []) { parent::__construct($o); }

    protected function typeName(): string { return 'string'; }

    public function values(): array { return $this->values; }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        if (! in_array($value, $this->values, true)) {
            $issues[] = ['path' => $path, 'code' => 'invalid_enum_value', 'message' => $this->invalidTypeError ?? ("Invalid enum value. Expected '" . implode("' | '", $this->values) . "'")];
            return Z::$FAIL;
        }
        return $value;
    }
}

final class ZLiteral extends ZType
{
    public function __construct(private mixed $literal) { parent::__construct(); }

    protected function typeName(): string { return 'literal'; }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        if ($value !== $this->literal) {
            $issues[] = ['path' => $path, 'code' => 'invalid_literal', 'message' => 'Invalid literal value, expected ' . json_encode($this->literal)];
            return Z::$FAIL;
        }
        return $value;
    }
}

final class ZArray extends ZType
{
    private array $checks = [];

    public function __construct(private ZType $item) { parent::__construct(); }

    protected function typeName(): string { return 'array'; }

    public function min(int $n, ?string $m = null): static { $c = clone $this; $c->checks[] = ['min', $n, $m]; return $c; }
    public function max(int $n, ?string $m = null): static { $c = clone $this; $c->checks[] = ['max', $n, $m]; return $c; }
    public function nonempty(?string $m = null): static { return $this->min(1, $m); }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        if (! is_array($value) || ! array_is_list($value)) {
            return $this->typeIssue($value, $path, $issues);
        }
        $n = count($value);
        foreach ($this->checks as [$k, $lim, $m]) {
            if ($k === 'min' && $n < $lim) $issues[] = ['path' => $path, 'code' => 'too_small', 'message' => $m ?? "Array must contain at least $lim element(s)"];
            if ($k === 'max' && $n > $lim) $issues[] = ['path' => $path, 'code' => 'too_big', 'message' => $m ?? "Array must contain at most $lim element(s)"];
        }
        $out = [];
        foreach ($value as $i => $item) {
            $r = $this->item->run($item, [...$path, $i], $issues);
            $out[] = $r === Z::$UNDEF ? null : $r;
        }
        return $out;
    }
}

final class ZObject extends ZType
{
    private string $unknown = 'strip';

    /** @param array<string,ZType> $shape */
    public function __construct(private array $shape) { parent::__construct(); }

    protected function typeName(): string { return 'object'; }

    public function shape(): array { return $this->shape; }
    public function strict(): static { $c = clone $this; $c->unknown = 'strict'; return $c; }
    public function passthrough(): static { $c = clone $this; $c->unknown = 'passthrough'; return $c; }
    public function extend(array $more): static { $c = clone $this; $c->shape = array_merge($this->shape, $more); $c->effects = []; return $c; }
    public function omit(array $keys): static { $c = clone $this; $c->shape = array_diff_key($this->shape, array_flip($keys)); $c->effects = []; return $c; }
    public function pick(array $keys): static { $c = clone $this; $c->shape = array_intersect_key($this->shape, array_flip($keys)); $c->effects = []; return $c; }
    public function partial(): static
    {
        $c = clone $this;
        $c->shape = array_map(fn (ZType $t) => $t->asPartial(), $this->shape);
        $c->effects = [];
        return $c;
    }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        if ($value instanceof \stdClass) {
            $value = json_decode(json_encode($value), true);
        }
        if (! is_array($value) || ($value !== [] && array_is_list($value))) {
            return $this->typeIssue($value, $path, $issues);
        }
        $out = [];
        foreach ($this->shape as $key => $schema) {
            $v = array_key_exists($key, $value) ? $value[$key] : Z::$UNDEF;
            $r = $schema->run($v, [...$path, $key], $issues);
            if ($r !== Z::$UNDEF && $r !== Z::$FAIL) {
                $out[$key] = $r;
            }
        }
        $extra = array_diff(array_keys($value), array_keys($this->shape));
        if ($extra) {
            if ($this->unknown === 'strict') {
                $issues[] = ['path' => $path, 'code' => 'unrecognized_keys', 'message' => "Unrecognized key(s) in object: '" . implode("', '", $extra) . "'"];
            } elseif ($this->unknown === 'passthrough') {
                foreach ($extra as $k) {
                    $out[$k] = $value[$k];
                }
            }
        }
        return $out;
    }
}

final class ZUnion extends ZType
{
    /** @param ZType[] $options */
    public function __construct(private array $options) { parent::__construct(); }

    protected function typeName(): string { return 'union'; }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        $dirty = null;
        foreach ($this->options as $opt) {
            $local = [];
            $r = $opt->run($value, $path, $local);
            if (! $local && $r !== Z::$FAIL) {
                return $r;
            }
            // A "dirty" result (right type, failed a check) wins over a type mismatch.
            $typeOnly = count(array_filter($local, fn ($i) => $i['code'] === 'invalid_type' && $i['path'] === $path)) === count($local);
            if (! $typeOnly && $dirty === null) {
                $dirty = $local;
            }
        }
        if ($dirty !== null) {
            array_push($issues, ...$dirty);
            return Z::$FAIL;
        }
        $issues[] = ['path' => $path, 'code' => 'invalid_union', 'message' => 'Invalid input'];
        return Z::$FAIL;
    }
}

final class ZRecord extends ZType
{
    public function __construct(private ZType $value, private ?ZType $key = null) { parent::__construct(); }

    protected function typeName(): string { return 'object'; }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        if ($value instanceof \stdClass) {
            $value = json_decode(json_encode($value), true);
        }
        if (! is_array($value) || ($value !== [] && array_is_list($value))) {
            return $this->typeIssue($value, $path, $issues);
        }
        $out = [];
        foreach ($value as $k => $v) {
            if ($this->key) {
                $this->key->run((string) $k, [...$path, $k], $issues);
            }
            $r = $this->value->run($v, [...$path, $k], $issues);
            if ($r !== Z::$UNDEF) {
                $out[(string) $k] = $r;
            }
        }
        return $out;
    }
}

final class ZAny extends ZType
{
    protected function typeName(): string { return 'any'; }

    public function run(mixed $value, array $path, array &$issues): mixed
    {
        return $value;
    }

    protected function check(mixed $value, array $path, array &$issues): mixed { return $value; }
}

final class ZNull extends ZType
{
    protected function typeName(): string { return 'null'; }

    protected function check(mixed $value, array $path, array &$issues): mixed
    {
        return $value === null ? null : $this->typeIssue($value, $path, $issues);
    }
}

/** An effect (transform / refine) chained after optional() / nullable() / default() / pipe(), as zod nests ZodEffects. */
final class ZWrap extends ZType
{
    public function __construct(private ZType $inner, private array $effect) { parent::__construct(); }

    protected function typeName(): string { return 'effects'; }

    protected function check(mixed $value, array $path, array &$issues): mixed { return $value; }

    public function isOptional(): bool { return $this->inner->isOptional() || parent::isOptional(); }

    public function run(mixed $value, array $path, array &$issues): mixed
    {
        if ($value === Z::$UNDEF && ($this->optional || $this->hasDefault)) {
            if (! $this->hasDefault) {
                return Z::$UNDEF;
            }
            $value = $this->default;
        }
        if ($value === null && $this->nullable) {
            return null;
        }
        $start = count($issues);
        $v = $this->inner->run($value, $path, $issues);
        if ($v === Z::$FAIL || count($issues) > $start) {
            return Z::$FAIL;
        }
        if ($this->effect[0] === 'refine') {
            if (! ($this->effect[1])($v)) {
                $issues[] = ['path' => array_merge($path, $this->effect[3]), 'code' => 'custom', 'message' => $this->effect[2]];
                return Z::$FAIL;
            }
            return $v;
        }
        $v = ($this->effect[1])($v, new ZCtx($issues, $path));
        return count($issues) > $start ? Z::$FAIL : $v;
    }
}
