<?php

namespace Tests\Unit;

use App\Mz\Services\ReportExport;
use App\Mz\Support\Dates;
use ReflectionMethod;
use Tests\TestCase;

class PdfTest extends TestCase
{
    public function test_pdf_export_generates_valid_pdf(): void
    {
        $meta = [
            'reference' => 'TEST-001',
            'generated_by' => 'Admin Test',
            'generated_at' => Dates::now(),
            'filters' => ['department' => 'Hymns and Arts'],
        ];
        $spec = [
            'title' => 'የሙከራ ሪፖርት / Test Report',
            'summary' => [['Total Items', 10]],
            'tables' => [
                [
                    'title' => 'አባላት / Members',
                    'columns' => ['ስም / Name', 'መለያ / ID', 'ሁኔታ / Status'],
                    'rows' => [
                        ['ዮሐንስ / Yohannes', 'መ/ሕ/ወ/1', 'active'],
                        ['ማርያም / Maryam', 'መ/ሕ/ወ/2', 'active'],
                    ],
                ],
            ],
        ];

        $method = new ReflectionMethod(ReportExport::class, 'pdf');
        $method->setAccessible(true);
        $content = $method->invoke(null, $spec, $meta);

        $this->assertNotEmpty($content);
        $this->assertStringStartsWith('%PDF-', $content);
    }
}
