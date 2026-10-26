<?php

namespace Tests\Unit;

use App\Mz\Services\Selections;
use Tests\TestCase;

class SelectionsTest extends TestCase
{
    public function test_categories_constants(): void
    {
        $this->assertSame('ለወረብ አገልግሎት የተመረጡ', Selections::CATEGORY_WEREB);
        $this->assertSame('ለመዝሙር አገልግሎት የተመረጡ', Selections::CATEGORY_MEZMUR);
        $this->assertContains(Selections::CATEGORY_WEREB, Selections::SERVICE_CATEGORIES);
        $this->assertContains(Selections::CATEGORY_MEZMUR, Selections::SERVICE_CATEGORIES);
    }

    public function test_components_exist(): void
    {
        $this->assertContains('course_attendance', Selections::COMPONENTS);
        $this->assertContains('exam', Selections::COMPONENTS);
        $this->assertContains('mezmur_attendance', Selections::COMPONENTS);
        $this->assertContains('contribution', Selections::COMPONENTS);
        $this->assertContains('participation', Selections::COMPONENTS);
    }

    public function test_default_required_reviewers(): void
    {
        $this->assertNotEmpty(Selections::DEFAULT_DEPARTMENTS);
        $this->assertContains('Hymns and Arts Department', Selections::DEFAULT_DEPARTMENTS);
        $this->assertContains('Education and Training Department', Selections::DEFAULT_DEPARTMENTS);
        $this->assertContains('Human Resources Management Department', Selections::DEFAULT_DEPARTMENTS);
    }

    public function test_category_validation(): void
    {
        $this->assertTrue(in_array('ለወረብ አገልግሎት የተመረጡ', Selections::SERVICE_CATEGORIES, true));
        $this->assertTrue(in_array('ለመዝሙር አገልግሎት የተመረጡ', Selections::SERVICE_CATEGORIES, true));
        $this->assertFalse(in_array('unknown_category', Selections::SERVICE_CATEGORIES, true));
    }

    public function test_nullable_service_category_allowed(): void
    {
        $allowed = [...Selections::SERVICE_CATEGORIES, null];
        $this->assertContains(null, $allowed);
        $this->assertContains(Selections::CATEGORY_WEREB, $allowed);
        $this->assertContains(Selections::CATEGORY_MEZMUR, $allowed);
    }

    public function test_bonus_config_supports_fixed_and_percentage(): void
    {
        $default = Selections::DEFAULT_CONFIG['bonus'];
        $this->assertArrayHasKey('type', $default);
        $this->assertArrayHasKey('points', $default);
        $this->assertArrayHasKey('base_component', $default);
        $this->assertSame('percentage', $default['type']);
        $this->assertSame('service_attendance', $default['base_component']);
        $this->assertLessThanOrEqual(Selections::BONUS_MAX, $default['max']);

        $merged = Selections::mergeConfig([
            'bonus' => [
                'type' => 'fixed',
                'points' => 10,
                'base_component' => 'course_attendance',
            ],
        ]);
        $this->assertSame('fixed', $merged['bonus']['type']);
        $this->assertSame(10, $merged['bonus']['points']);
        $this->assertSame('course_attendance', $merged['bonus']['base_component']);
    }
    public function test_merge_config_preserves_contribution_month_range(): void
    {
        $default = Selections::DEFAULT_CONFIG['contribution'];
        $this->assertArrayHasKey('late_credit', $default);
        $this->assertArrayHasKey('start_month', $default);
        $this->assertArrayHasKey('end_month', $default);
        $this->assertArrayHasKey('year', $default);

        $merged = Selections::mergeConfig([
            'contribution' => [
                'late_credit' => 0.8,
                'year' => 2019,
                'start_month' => 1,
                'end_month' => 5,
            ],
        ]);
        $this->assertSame(0.8, $merged['contribution']['late_credit']);
        $this->assertSame(2019, $merged['contribution']['year']);
        $this->assertSame(1, $merged['contribution']['start_month']);
        $this->assertSame(5, $merged['contribution']['end_month']);
    }

    public function test_contribution_month_range_validation_schema(): void
    {
        $schema = \App\Mz\Support\Z::object([
            'late_credit' => \App\Mz\Support\Z::number()->min(0)->max(1)->optional(),
            'year' => \App\Mz\Support\Z::coerceNumber()->int()->min(1900)->max(2200)->nullable()->optional(),
            'start_month' => \App\Mz\Support\Z::coerceNumber()->int()->min(1)->max(13)->nullable()->optional(),
            'end_month' => \App\Mz\Support\Z::coerceNumber()->int()->min(1)->max(13)->nullable()->optional(),
        ])->strict()->refine(function ($c) {
            $sm = $c['start_month'] ?? null;
            $em = $c['end_month'] ?? null;
            if (($sm === null) !== ($em === null)) {
                return false;
            }
            if ($sm !== null && $em !== null && $sm > $em) {
                return false;
            }
            return true;
        }, 'MONTH_RANGE_INVALID');

        // Valid ranges
        $v1 = \App\Mz\Support\Z::parse($schema, ['start_month' => 1, 'end_month' => 5, 'year' => 2019]);
        $this->assertSame(1, $v1['start_month']);
        $this->assertSame(5, $v1['end_month']);
        $this->assertSame(2019, $v1['year']);

        $v2 = \App\Mz\Support\Z::parse($schema, ['start_month' => null, 'end_month' => null, 'year' => null]);
        $this->assertNull($v2['start_month']);
        $this->assertNull($v2['end_month']);

        $v3 = \App\Mz\Support\Z::parse($schema, ['late_credit' => 1]);
        $this->assertSame(1, $v3['late_credit']);

        // Invalid: start > end
        $this->expectException(\App\Mz\Support\ApiError::class);
        \App\Mz\Support\Z::parse($schema, ['start_month' => 6, 'end_month' => 2]);
    }
}

