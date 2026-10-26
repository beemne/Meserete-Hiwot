<?php

namespace App\Mz\Support;

use RuntimeException;
use ZipArchive;

/**
 * Minimal .xlsx (Office Open XML) reader / writer for bulk import — enough for plain tables:
 * text, numbers, booleans, multi-line cells. No formulas, styles or dates are interpreted (cells are
 * read as their stored text). No third-party package needed (ext-zip + SimpleXML).
 */
final class Xlsx
{
    /** Rows of the first worksheet as arrays of strings (empty trailing rows dropped). */
    public static function read(string $binary): array
    {
        $tmp = tempnam(sys_get_temp_dir(), 'mzx');
        file_put_contents($tmp, $binary);
        $zip = new ZipArchive();
        try {
            if ($zip->open($tmp) !== true) throw new RuntimeException('NOT_XLSX');
            $shared = [];
            if (($xml = $zip->getFromName('xl/sharedStrings.xml')) !== false) {
                $sx = self::xml($xml);
                foreach ($sx->si as $si) $shared[] = self::text($si);
            }
            $sheetPath = self::firstSheetPath($zip);
            $xml = $zip->getFromName($sheetPath);
            if ($xml === false) throw new RuntimeException('NOT_XLSX');
            $sheet = self::xml($xml);
            $rows = [];
            foreach ($sheet->sheetData->row ?? [] as $row) {
                $r = [];
                $next = 0;
                foreach ($row->c as $c) {
                    $ref = (string) $c['r'];
                    $col = $ref !== '' ? self::colIndex($ref) : $next;
                    $t = (string) $c['t'];
                    $v = match ($t) {
                        's' => $shared[(int) $c->v] ?? '',
                        'inlineStr' => self::text($c->is),
                        'b' => ((string) $c->v) === '1' ? 'true' : 'false',
                        default => (string) $c->v,
                    };
                    while (count($r) < $col) $r[] = '';
                    $r[$col] = $v;
                    $next = $col + 1;
                }
                $rows[(int) $row['r'] > 0 ? (int) $row['r'] - 1 : count($rows)] = $r;
            }
            if (! $rows) return [];
            $out = [];
            for ($i = 0, $max = max(array_keys($rows)); $i <= $max; $i++) $out[] = $rows[$i] ?? [];
            while ($out && ! array_filter(end($out), fn ($x) => trim((string) $x) !== '')) array_pop($out);
            return $out;
        } finally {
            $zip->close();
            @unlink($tmp);
        }
    }

    /**
     * A workbook from [sheet name => rows]; the first row of each sheet is the (bold) header.
     * @param array<string, array<int, array<int, string|int|float|null>>> $sheets
     */
    public static function write(array $sheets, bool $freezeHeader = false): string
    {
        $tmp = tempnam(sys_get_temp_dir(), 'mzx');
        $zip = new ZipArchive();
        $zip->open($tmp, ZipArchive::OVERWRITE);
        $names = array_keys($sheets);
        $ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            . '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'
            . '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            . '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>';
        foreach ($names as $i => $_) $ct .= '<Override PartName="/xl/worksheets/sheet' . ($i + 1) . '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>';
        $zip->addFromString('[Content_Types].xml', $ct . '</Types>');
        $zip->addFromString('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');
        $wb = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>';
        $rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">';
        foreach ($names as $i => $n) {
            $wb .= '<sheet name="' . self::esc(mb_substr($n, 0, 31)) . '" sheetId="' . ($i + 1) . '" r:id="rId' . ($i + 1) . '"/>';
            $rels .= '<Relationship Id="rId' . ($i + 1) . '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' . ($i + 1) . '.xml"/>';
        }
        $rels .= '<Relationship Id="rId' . (count($names) + 1) . '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>';
        $zip->addFromString('xl/workbook.xml', $wb . '</sheets></workbook>');
        $zip->addFromString('xl/_rels/workbook.xml.rels', $rels . '</Relationships>');
        // Style 1: bold header; style 2: wrapped text (multi-line lyrics).
        $zip->addFromString('xl/styles.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            . '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
            . '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
            . '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
            . '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
            . '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
            . '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf></cellXfs>'
            . '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>');
        foreach (array_values($sheets) as $i => $rows) {
            $x = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">';
            // Report exports keep the header row visible while scrolling.
            if ($freezeHeader) $x .= '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>';
            $widths = [];
            foreach ($rows as $row) foreach (array_values($row) as $j => $v) $widths[$j] = min(60, max($widths[$j] ?? 10, mb_strlen(strtok((string) $v, "\n") ?: '') + 2));
            if ($widths) {
                $x .= '<cols>';
                foreach ($widths as $j => $w) $x .= '<col min="' . ($j + 1) . '" max="' . ($j + 1) . '" width="' . $w . '" customWidth="1"/>';
                $x .= '</cols>';
            }
            $x .= '<sheetData>';
            foreach (array_values($rows) as $r => $row) {
                $x .= '<row r="' . ($r + 1) . '">';
                foreach (array_values($row) as $j => $v) {
                    if ($v === null || $v === '') continue;
                    $ref = self::colName($j) . ($r + 1);
                    $style = $r === 0 ? 1 : (str_contains((string) $v, "\n") ? 2 : 0);
                    $x .= is_int($v) || is_float($v)
                        ? '<c r="' . $ref . '" s="' . $style . '"><v>' . $v . '</v></c>'
                        : '<c r="' . $ref . '" s="' . $style . '" t="inlineStr"><is><t xml:space="preserve">' . self::esc((string) $v) . '</t></is></c>';
                }
                $x .= '</row>';
            }
            $zip->addFromString('xl/worksheets/sheet' . ($i + 1) . '.xml', $x . '</sheetData></worksheet>');
        }
        $zip->close();
        $data = (string) file_get_contents($tmp);
        @unlink($tmp);
        return $data;
    }

    private static function firstSheetPath(ZipArchive $zip): string
    {
        $wb = $zip->getFromName('xl/workbook.xml');
        $rels = $zip->getFromName('xl/_rels/workbook.xml.rels');
        if ($wb !== false && $rels !== false) {
            $w = self::xml($wb);
            $first = $w->sheets->sheet[0] ?? null;
            $rid = $first ? (string) $first->attributes('http://schemas.openxmlformats.org/officeDocument/2006/relationships')['id'] : '';
            foreach (self::xml($rels)->Relationship as $rel) {
                if ((string) $rel['Id'] === $rid) {
                    $t = ltrim((string) $rel['Target'], '/');
                    return str_starts_with($t, 'xl/') ? $t : 'xl/' . $t;
                }
            }
        }
        return 'xl/worksheets/sheet1.xml';
    }

    private static function xml(string $s): \SimpleXMLElement
    {
        $x = simplexml_load_string($s, \SimpleXMLElement::class, LIBXML_NONET);
        if ($x === false) throw new RuntimeException('NOT_XLSX');
        return $x;
    }

    /** Text of a <si> / <is> (plain <t> or rich-text runs <r><t>). */
    private static function text(?\SimpleXMLElement $n): string
    {
        if (! $n) return '';
        if (isset($n->t)) return (string) $n->t;
        $s = '';
        foreach ($n->r as $r) $s .= (string) $r->t;
        return $s;
    }

    private static function colIndex(string $ref): int
    {
        preg_match('/^([A-Z]+)/', strtoupper($ref), $m);
        $n = 0;
        foreach (str_split($m[1] ?? 'A') as $ch) $n = $n * 26 + (ord($ch) - 64);
        return $n - 1;
    }

    private static function colName(int $i): string
    {
        $s = '';
        for ($n = $i + 1; $n > 0; $n = intdiv($n - 1, 26)) $s = chr(65 + ($n - 1) % 26) . $s;
        return $s;
    }

    private static function esc(string $s): string
    {
        // XML 1.0 cannot hold most control characters.
        $s = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F]/', '', $s);
        return htmlspecialchars($s, ENT_XML1 | ENT_QUOTES, 'UTF-8');
    }
}
