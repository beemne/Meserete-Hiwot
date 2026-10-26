<?php

namespace App\Mz\Services;

use App\Mz\Support\ApiError;
use App\Mz\Support\ContentSchemas;
use App\Mz\Support\MemberSchemas;
use App\Mz\Support\V;
use App\Mz\Support\Xlsx;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\DB;

/**
 * Bulk import from files the admin prepares (port of importService.js). Every import can run as a
 * dry run first: rows are parsed and validated, nothing is written.
 *
 * Every kind is a table — one row per item, the first row names the columns (English or Amharic):
 * an Excel workbook (.xlsx, first sheet; the downloadable template has examples and the allowed
 * values), a .csv file, or rows pasted from Excel / Google Sheets (tab separated).
 *  - Mezmurs: title, category (name or "Parent > Child"), lyrics (multi-line cell), tags, status,
 *    youtube, lrc. The older .txt format (blocks separated by ===) is still read.
 *  - Categories: name, parent, description, order, active.
 *  - Users: full_name, phone, email, password, member_group, member_type, gender, can_login (an empty
 *    password gets a temporary one, returned once; the user must change it).
 */
final class Import
{
    public const MAX_ROWS = 2000;

    public const TEMPLATES = [
        'mezmurs' => "Title: የመስቀል መዝሙር\nCategory: የመስቀል መዝሙራት\nTags: መስቀል, በዓል\nStatus: published\n\nመስመር አንድ\nመስመር ሁለት\n===\nTitle: ሁለተኛ መዝሙር\nCategory: የመስቀል መዝሙራት > የጠዋት\nStatus: draft\n\nየመዝሙሩ ግጥም እዚህ ይገባል\n",
        'categories' => "name,parent,description,order,active\nየመስቀል መዝሙራት,,የመስከረም 17 መዝሙራት,1,true\nየጠዋት,የመስቀል መዝሙራት,,1,true\nየዐቢይ ጾም መዝሙራት,,,2,true\n",
        'users' => "full_name,phone,email,password\nአበበ በቀለ,0911223344,,\nሰላም ተስፋዬ,0922334455,selam@example.com,secret123\n",
    ];

    private static function stripBom(string $s): string
    {
        return str_starts_with($s, "\u{FEFF}") ? substr($s, 3) : $s;
    }

    public const FORMATS = ['auto', 'txt', 'csv', 'tsv', 'xlsx'];

    /** Column names accepted besides the English ones (Amharic headings of the templates). */
    private const ALIASES = [
        'ርዕስ' => 'title', 'ምድብ' => 'category', 'ግጥም' => 'lyrics', 'መለያዎች' => 'tags', 'ሁኔታ' => 'status', 'ዩቲዩብ' => 'youtube',
        'ስም' => 'name', 'ወላጅ ምድብ' => 'parent', 'መግለጫ' => 'description', 'ቅደም ተከተል' => 'order', 'ንቁ' => 'active',
        'ሙሉ ስም' => 'full_name', 'ስልክ' => 'phone', 'ኢሜይል' => 'email', 'ፒን' => 'password', 'pin' => 'password', 'የይለፍ ቃል' => 'password', 'የአባል ምድብ' => 'member_group',
        'ተማሪ/ሠራተኛ' => 'member_type', 'ጾታ' => 'gender', 'መግባት ይችላል' => 'can_login',
    ];

    /** The rows of an import (xlsx content arrives base64-encoded). */
    public static function table(string $content, string $format): array
    {
        if ($format === 'xlsx') {
            $bin = base64_decode($content, true);
            if ($bin === false) throw ApiError::field('content', 'INVALID_FILE');
            try {
                return Xlsx::read($bin);
            } catch (\RuntimeException) {
                throw ApiError::field('content', 'INVALID_FILE');
            }
        }
        if ($format === 'auto') $format = str_contains(strtok(self::stripBom($content), "\n") ?: '', "\t") ? 'tsv' : 'csv';
        return self::parseCsv($content, $format === 'tsv' ? "\t" : ',');
    }

    /** Old Mezmur .txt (blocks with "Title:")? */
    private static function looksLikeMezmurText(string $content): bool
    {
        foreach (explode("\n", self::stripBom($content)) as $l) {
            if (trim($l) === '') continue;
            return (bool) preg_match('/^\s*title\s*:/iu', $l);
        }
        return false;
    }

    /** RFC-4180 CSV (quotes, escaped quotes, separators/newlines inside quotes); also tab separated. */
    public static function parseCsv(string $input, string $sep = ','): array
    {
        $src = self::stripBom($input);
        $rows = [];
        $row = [];
        $cell = '';
        $quoted = false;
        $len = strlen($src);
        for ($i = 0; $i < $len; $i++) {
            $c = $src[$i];
            if ($quoted) {
                if ($c === '"' && ($src[$i + 1] ?? '') === '"') {
                    $cell .= '"';
                    $i++;
                } elseif ($c === '"') {
                    $quoted = false;
                } else {
                    $cell .= $c;
                }
            } elseif ($c === '"') {
                $quoted = true;
            } elseif ($c === $sep) {
                $row[] = $cell;
                $cell = '';
            } elseif ($c === "\n" || $c === "\r") {
                if ($c === "\r" && ($src[$i + 1] ?? '') === "\n") $i++;
                $row[] = $cell;
                $rows[] = $row;
                $row = [];
                $cell = '';
            } else {
                $cell .= $c;
            }
        }
        if ($cell !== '' || $row) {
            $row[] = $cell;
            $rows[] = $row;
        }
        return array_values(array_filter($rows, fn ($r) => (bool) array_filter($r, fn ($x) => trim($x) !== '')));
    }

    /** @return array{error: ?string, items: array<int, array{line:int, data:array<string,string>}>} */
    private static function objects(array $rows, array $expected): array
    {
        if (! $rows) return ['error' => 'EMPTY_FILE', 'items' => []];
        $header = array_map(function ($h) {
            $k = mb_strtolower(trim((string) $h));
            $k = self::ALIASES[$k] ?? self::ALIASES[trim((string) $h)] ?? $k;
            return str_replace([' ', '-'], '_', $k);
        }, $rows[0]);
        $missing = array_values(array_diff($expected, $header));
        if ($missing) return ['error' => 'MISSING_COLUMNS: ' . implode(', ', $missing), 'items' => []];
        $items = [];
        foreach (array_slice($rows, 1) as $i => $r) {
            if (! array_filter($r, fn ($x) => trim((string) $x) !== '')) continue;
            $data = [];
            foreach ($header as $j => $h) $data[$h] = trim((string) ($r[$j] ?? ''));
            $items[] = ['line' => $i + 2, 'data' => $data];
        }
        return ['error' => null, 'items' => $items];
    }

    private static function csvObjects(string $content, array $expected, string $format = 'auto'): array
    {
        return self::objects(self::table($content, $format), $expected);
    }

    public static function parseMezmurText(string $content): array
    {
        $lines = explode("\n", preg_replace("/\r\n?/", "\n", self::stripBom($content)));
        $blocks = [];
        $cur = ['line' => 1, 'lines' => []];
        foreach ($lines as $i => $l) {
            if (preg_match('/^\s*={3,}\s*$/', $l)) {
                $blocks[] = $cur;
                $cur = ['line' => $i + 2, 'lines' => []];
            } else {
                $cur['lines'][] = $l;
            }
        }
        $blocks[] = $cur;
        $out = [];
        foreach ($blocks as $b) {
            if (! array_filter($b['lines'], fn ($l) => trim($l) !== '')) continue;
            $head = [];
            $i = 0;
            $n = count($b['lines']);
            while ($i < $n && trim($b['lines'][$i]) === '') $i++;
            for (; $i < $n; $i++) {
                if (! preg_match('/^\s*(title|category|tags|status|youtube)\s*:\s*(.*)$/iu', $b['lines'][$i], $m)) break;
                $head[strtolower($m[1])] = trim($m[2]);
            }
            $out[] = ['line' => $b['line'], 'head' => $head, 'lyrics' => trim(implode("\n", array_slice($b['lines'], $i)))];
        }
        return $out;
    }

    private static function errorText(array $errors): string
    {
        return implode('; ', array_map(fn ($e) => ($e['field'] ?: 'value') . ': ' . $e['message'], $errors));
    }

    /** Category lookup by name or "Parent > Child" path (case-insensitive), incl. rows created in this run. */
    private static function categoryResolver(): object
    {
        return new class {
            private array $byId = [];
            private array $index = [];

            public function __construct()
            {
                $rows = DB::table('categories')->select('id', 'parent_id', 'name')->get();
                foreach ($rows as $r) $this->byId[$r->id] = $r;
                foreach ($rows as $r) $this->add($r);
            }

            private function pathOf(object $r): string
            {
                $parts = [];
                for ($c = $r, $n = 0; $c && $n < 50; $c = $this->byId[$c->parent_id ?? 0] ?? null, $n++) array_unshift($parts, $c->name);
                return mb_strtolower(implode(' > ', $parts));
            }

            public function add(object $r): void
            {
                $this->byId[$r->id] = $r;
                foreach ([$this->pathOf($r), mb_strtolower($r->name)] as $key) {
                    if (! isset($this->index[$key])) $this->index[$key] = $r->id;
                }
            }

            public function find(string $s): ?int
            {
                $norm = mb_strtolower(implode(' > ', array_values(array_filter(array_map('trim', explode('>', $s)), fn ($p) => $p !== ''))));
                return $this->index[$norm] ?? null;
            }
        };
    }

    /** Mezmur entries [line, head{title, category, tags, status, youtube}, lyrics, lrc] from any format. */
    private static function mezmurEntries(string $content, string $format): array
    {
        if ($format === 'txt' || ($format === 'auto' && self::looksLikeMezmurText($content))) return self::parseMezmurText($content);
        ['error' => $error, 'items' => $items] = self::objects(self::table($content, $format), ['title', 'lyrics']);
        if ($error) throw ApiError::field('content', $error);
        return array_map(fn ($it) => [
            'line' => $it['line'],
            'head' => array_filter(['title' => $it['data']['title'] ?? '', 'category' => $it['data']['category'] ?? '', 'tags' => $it['data']['tags'] ?? '', 'status' => $it['data']['status'] ?? '', 'youtube' => $it['data']['youtube'] ?? ''], fn ($v) => $v !== ''),
            'lyrics' => str_replace("\r\n", "\n", $it['data']['lyrics'] ?? ''),
            'lrc' => ($it['data']['lrc'] ?? '') ?: null,
        ], $items);
    }

    public static function mezmurs(array $actx, string $content, bool $dryRun, string $format = 'auto'): array
    {
        $cats = self::categoryResolver();
        $results = [];
        $seen = [];
        foreach (array_slice(self::mezmurEntries($content, $format), 0, self::MAX_ROWS) as $b) {
            $title = $b['head']['title'] ?? null;
            $categoryName = $b['head']['category'] ?? '';
            $categoryId = $categoryName !== '' ? $cats->find($categoryName) : null;
            if ($categoryName !== '' && ! $categoryId) {
                $results[] = ['line' => $b['line'], 'title' => $title, 'ok' => false, 'error' => "Category not found: $categoryName"];
                continue;
            }
            $input = [
                'title' => $title ?? '',
                'lyrics' => $b['lyrics'],
                'category_id' => $categoryId,
                'status' => strtolower(($b['head']['status'] ?? '') ?: 'draft'),
                'youtube_url' => ($b['head']['youtube'] ?? '') ?: null,
            ];
            if (! empty($b['lrc'])) $input['lrc'] = $b['lrc'];
            if (! empty($b['head']['tags'])) $input['tags'] = array_values(array_filter(array_map('trim', explode(',', $b['head']['tags'])), fn ($t) => $t !== ''));
            [$ok, $data, $errors] = Z::safeParse(ContentSchemas::mezmurCreate(), $input);
            if (! $ok) {
                $results[] = ['line' => $b['line'], 'title' => $title, 'ok' => false, 'error' => self::errorText($errors)];
                continue;
            }
            // Titles are unique across all Mezmurs (not only within a category).
            $dupKey = Mezmurs::normalizeTitle($data['title']);
            if (isset($seen[$dupKey])) {
                $results[] = ['line' => $b['line'], 'title' => $data['title'], 'ok' => false, 'skipped' => true, 'error' => 'Twice in this file'];
                continue;
            }
            $seen[$dupKey] = true;
            if (Mezmurs::titleTaken($data['title'])) {
                $results[] = ['line' => $b['line'], 'title' => $data['title'], 'ok' => false, 'skipped' => true, 'error' => 'Already exists (a Mezmur with this title)'];
                continue;
            }
            if ($dryRun) {
                $results[] = ['line' => $b['line'], 'title' => $data['title'], 'ok' => true];
                continue;
            }
            try {
                $m = Mezmurs::create($actx, $data);
                $results[] = ['line' => $b['line'], 'title' => $m['title'], 'ok' => true, 'id' => $m['id']];
            } catch (\Throwable $e) {
                $results[] = ['line' => $b['line'], 'title' => $data['title'], 'ok' => false, 'error' => $e->getMessage()];
            }
        }
        return self::summarize($results, $dryRun);
    }

    public static function categories(array $actx, string $content, bool $dryRun, string $format = 'auto'): array
    {
        ['error' => $error, 'items' => $items] = self::csvObjects($content, ['name'], $format);
        if ($error) return ['dry_run' => $dryRun, 'error' => $error, 'total' => 0, 'ok' => 0, 'failed' => 0, 'rows' => []];
        $cats = self::categoryResolver();
        $results = [];
        $fakeId = -1; // dry-run placeholders so later rows can reference earlier ones
        foreach (array_slice($items, 0, self::MAX_ROWS) as ['line' => $line, 'data' => $data]) {
            $name = $data['name'];
            $parent = $data['parent'] ?? '';
            $parentId = $parent !== '' ? $cats->find($parent) : null;
            if ($parent !== '' && ! $parentId) {
                $results[] = ['line' => $line, 'title' => $name, 'ok' => false, 'error' => "Parent not found: $parent"];
                continue;
            }
            $input = ['name' => $name, 'parent_id' => $parentId && $parentId > 0 ? $parentId : null, 'description' => ($data['description'] ?? '') ?: null];
            if (($data['order'] ?? '') !== '') $input['display_order'] = is_numeric($data['order']) ? $data['order'] + 0 : NAN;
            if (($data['active'] ?? '') !== '') $input['is_active'] = ! in_array(strtolower($data['active']), ['false', '0', 'no'], true);
            [$ok, $parsed, $errors] = Z::safeParse(ContentSchemas::categoryCreate(), $input);
            if (! $ok) {
                $results[] = ['line' => $line, 'title' => $name, 'ok' => false, 'error' => self::errorText($errors)];
                continue;
            }
            if ($cats->find($parent !== '' ? "$parent > $name" : $name)) {
                $results[] = ['line' => $line, 'title' => $name, 'ok' => false, 'skipped' => true, 'error' => 'Already exists'];
                continue;
            }
            if ($dryRun) {
                $cats->add((object) ['id' => $fakeId--, 'parent_id' => $parentId, 'name' => $name]);
                $results[] = ['line' => $line, 'title' => $name, 'ok' => true];
                continue;
            }
            try {
                $c = Categories::create($actx, $parsed);
                $cats->add((object) ['id' => $c['id'], 'parent_id' => $c['parent_id'] ?? null, 'name' => $c['name']]);
                $results[] = ['line' => $line, 'title' => $c['name'], 'ok' => true, 'id' => $c['id']];
            } catch (\Throwable $e) {
                $results[] = ['line' => $line, 'title' => $name, 'ok' => false, 'error' => $e->getMessage()];
            }
        }
        return self::summarize($results, $dryRun);
    }

    public static function users(array $actx, string $content, bool $dryRun, string $format = 'auto'): array
    {
        ['error' => $error, 'items' => $items] = self::csvObjects($content, ['full_name', 'phone'], $format);
        if ($error) return ['dry_run' => $dryRun, 'error' => $error, 'total' => 0, 'ok' => 0, 'failed' => 0, 'rows' => []];
        $schema = Z::object([
            'full_name' => V::text(2, 150), 'phone' => V::phone(), 'email' => V::optionalEmail(), 'password' => V::password()->optional(),
            'member_group' => V::memberGroup()->optional(),
            'member_type' => Z::enum(['student', 'worker'])->optional(),
            'can_login' => Z::boolean()->optional(),
            'profile' => Z::object(['gender' => Z::enum(['male', 'female'])->optional()])->optional(),
        ]);
        $results = [];
        $seen = [];
        foreach (array_slice($items, 0, self::MAX_ROWS) as ['line' => $line, 'data' => $data]) {
            $input = ['full_name' => $data['full_name'], 'phone' => $data['phone'], 'email' => ($data['email'] ?? '') ?: null];
            if (($data['password'] ?? '') !== '') $input['password'] = $data['password'];
            if (($data['member_group'] ?? '') !== '') $input['member_group'] = self::choice($data['member_group'], self::groupChoices());
            if (($data['member_type'] ?? '') !== '') $input['member_type'] = self::choice($data['member_type'], ['student' => ['ተማሪ'], 'worker' => ['ሠራተኛ', 'ሰራተኛ']]);
            if (($data['gender'] ?? '') !== '') $input['profile'] = ['gender' => self::choice($data['gender'], ['male' => ['ወንድ', 'm'], 'female' => ['ሴት', 'f']])];
            if (($data['can_login'] ?? '') !== '') $input['can_login'] = ! in_array(mb_strtolower($data['can_login']), ['false', '0', 'no', 'አይ', 'አይችልም'], true);
            [$ok, $u, $errors] = Z::safeParse($schema, $input);
            if (! $ok) {
                $results[] = ['line' => $line, 'title' => $data['full_name'], 'ok' => false, 'error' => self::errorText($errors)];
                continue;
            }
            if (isset($seen[$u['phone']])) {
                $results[] = ['line' => $line, 'title' => $u['full_name'], 'ok' => false, 'error' => 'Duplicate phone in file'];
                continue;
            }
            $seen[$u['phone']] = true;
            $taken = DB::table('users')->where('phone', $u['phone'])->orWhere(fn ($w) => ! empty($u['email']) ? $w->where('email', $u['email']) : $w->whereRaw('1 = 0'))->exists();
            if ($taken) {
                $results[] = ['line' => $line, 'title' => $u['full_name'], 'ok' => false, 'skipped' => true, 'error' => 'Phone or email already registered'];
                continue;
            }
            if ($dryRun) {
                $results[] = ['line' => $line, 'title' => $u['full_name'], 'ok' => true];
                continue;
            }
            try {
                $out = UserAdmin::create($actx, $u);
                $row = ['line' => $line, 'title' => $u['full_name'], 'ok' => true, 'id' => $out['user']['id'], 'phone' => $u['phone']];
                if (! empty($out['temporary_password'])) $row['temporary_password'] = $out['temporary_password'];
                $results[] = $row;
            } catch (\Throwable $e) {
                $results[] = ['line' => $line, 'title' => $u['full_name'], 'ok' => false, 'error' => $e->getMessage()];
            }
        }
        return self::summarize($results, $dryRun);
    }

    /** A value given in English or Amharic → its stored key (unknown text is kept, then rejected by validation). */
    /** Member type words accepted in imports: each type's key, Amharic and English name (+ common spellings). */
    private static function groupChoices(): array
    {
        $map = ['children' => ['ሕፃናት', 'ህፃናት', 'child'], 'youth_adult' => ['ወጣት', 'youth', 'adult'], 'married' => ['ባለትዳር']];
        foreach (MemberGroups::list(true) as $g) {
            $map[$g['key']] = array_values(array_filter(array_merge($map[$g['key']] ?? [], [$g['name'], $g['name_en']])));
        }
        return $map;
    }

    private static function choice(string $v, array $map): string
    {
        $x = mb_strtolower(trim($v));
        foreach ($map as $key => $words) {
            if ($x === $key || in_array($x, array_map('mb_strtolower', $words), true)) return $key;
        }
        return $x;
    }

    /** The template workbook of a kind: the table with examples, plus the allowed values. */
    public static function templateXlsx(string $kind): string
    {
        $sheets = match ($kind) {
            'mezmurs' => [
                'Mezmurs' => [
                    ['title', 'category', 'lyrics', 'tags', 'status', 'youtube', 'lrc'],
                    ['የመስቀል መዝሙር', 'የመስቀል መዝሙራት', "መስመር አንድ\nመስመር ሁለት\n\nአዝማች", 'መስቀል, በዓል', 'published', '', ''],
                    ['ሁለተኛ መዝሙር', 'የመስቀል መዝሙራት > የጠዋት', 'የመዝሙሩ ግጥም እዚህ ይገባል', '', 'draft', '', ''],
                ],
                'Categories' => array_merge([['category (copy into the category column)']], array_map(fn ($p) => [$p], self::categoryPaths())),
                'Help' => [
                    ['column', 'what to write'],
                    ['title', 'required'],
                    ['category', 'a name from the Categories sheet (or "Parent > Child"); empty = none'],
                    ['lyrics', 'required — the whole lyrics in one cell (Alt+Enter for a new line)'],
                    ['tags', 'optional, separated by commas'],
                    ['status', 'draft | published | archived (empty = draft)'],
                    ['youtube', 'optional YouTube link'],
                    ['lrc', 'optional time-synced lyrics ([00:12.50] line …)'],
                ],
            ],
            'categories' => [
                'Categories' => [
                    ['name', 'parent', 'description', 'order', 'active'],
                    ['የመስቀል መዝሙራት', '', 'የመስከረም 17 መዝሙራት', 1, 'true'],
                    ['የጠዋት', 'የመስቀል መዝሙራት', '', 1, 'true'],
                ],
                'Existing' => array_merge([['existing categories']], array_map(fn ($p) => [$p], self::categoryPaths())),
            ],
            default => [
                'Users' => [
                    ['full_name', 'phone', 'email', 'pin', 'member_group', 'member_type', 'gender', 'can_login'],
                    ['አበበ በቀለ', '0911223344', '', '', 'youth_adult', 'student', 'male', 'true'],
                    ['ሰላም ተስፋዬ', '0922334455', 'selam@example.com', '', 'married', 'worker', 'female', 'true'],
                ],
                'Values' => [
                    ['column', 'allowed values'],
                    ['member_group', implode(' | ', array_map(fn ($g) => "{$g['key']} ({$g['name']})", MemberGroups::list()))],
                    ['member_type', 'student (ተማሪ) | worker (ሠራተኛ)'],
                    ['gender', 'male (ወንድ) | female (ሴት)'],
                    ['can_login', 'true | false'],
                    ['pin', '4 to 6 digits; empty = a temporary PIN is made and shown once'],
                ],
            ],
        };
        return Xlsx::write($sheets);
    }

    /** "Parent > Child" paths of the existing categories. */
    private static function categoryPaths(): array
    {
        $rows = DB::table('categories')->select('id', 'parent_id', 'name')->get()->keyBy('id');
        $out = [];
        foreach ($rows as $r) {
            $parts = [];
            for ($c = $r, $n = 0; $c && $n < 20; $c = $rows[$c->parent_id] ?? null, $n++) array_unshift($parts, $c->name);
            $out[] = implode(' > ', $parts);
        }
        sort($out);
        return $out;
    }

    private static function summarize(array $rows, bool $dryRun): array
    {
        return [
            'dry_run' => $dryRun,
            'total' => count($rows),
            'ok' => count(array_filter($rows, fn ($r) => $r['ok'])),
            'skipped' => count(array_filter($rows, fn ($r) => ! empty($r['skipped']))),
            'failed' => count(array_filter($rows, fn ($r) => ! $r['ok'] && empty($r['skipped']))),
            'rows' => $rows,
        ];
    }
}
