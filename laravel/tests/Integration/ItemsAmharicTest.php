<?php

namespace Tests\Integration;

use Illuminate\Support\Facades\DB;

class ItemsAmharicTest extends IntegrationTestCase
{
    public function test_items_carry_the_amharic_category_name_and_search_works_in_amharic(): void
    {
        $admin = $this->member(['items.manage']);
        DB::table('item_categories')->updateOrInsert(['key' => 'it_drums'], ['name' => 'የከበሮ መሣሪያዎች', 'name_en' => 'Drums', 'code' => 'KB']);
        DB::table('items')->insert(['name' => 'ከበሮ ሙከራ', 'code' => 'IT-KB-001', 'category' => 'it_drums', 'description' => 'ለዝማሬ የሚያገለግል', 'quantity' => 2, 'available_quantity' => 2]);

        foreach (['ከበሮ ሙከራ', 'የከበሮ መሣሪያ', 'ለዝማሬ', 'Drums'] as $q) {
            $res = $this->as($admin, 'GET', 'items?q=' . rawurlencode($q));
            $res->assertOk();
            $row = collect($res->json('data'))->firstWhere('code', 'IT-KB-001');
            $this->assertNotNull($row, "search '$q'");
            $this->assertSame('የከበሮ መሣሪያዎች', $row['category_name']);
            $this->assertSame('it_drums', $row['category'], 'the stored key is unchanged');
        }
    }
}
