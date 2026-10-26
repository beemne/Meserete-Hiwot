<?php

namespace App\Mz\Support;

/** Content validators (port of validators/content.js). */
final class ContentSchemas
{
    public static function categoryCreate(): ZObject
    {
        return Z::object([
            'parent_id' => V::id()->nullable()->optional(),
            'name' => V::text(1, 150),
            'description' => V::optionalText(1000),
            'icon' => Z::string()->trim()->max(60)->regex('/^[a-z0-9_-]*$/', 'INVALID_ICON')->nullable()->optional(),
            'display_order' => Z::number()->int()->min(0)->max(100000)->optional(),
            'is_active' => Z::boolean()->optional(),
        ]);
    }

    public static function categoryUpdate(): ZObject
    {
        return self::categoryCreate()->partial()->strict();
    }

    public static function categoryReorder(): ZObject
    {
        return Z::object(['items' => Z::array(Z::object(['id' => V::id(), 'display_order' => Z::number()->int()->min(0)->max(100000)]))->min(1)->max(500)]);
    }

    public static function mezmurCreate(): ZObject
    {
        return Z::object([
            'title' => V::text(1, 255),
            'lyrics' => V::text(1, 100000),
            'description' => V::optionalText(2000),
            'category_id' => V::id()->nullable()->optional(),
            'status' => Z::enum(['draft', 'published', 'archived'])->optional(),
            'is_featured' => Z::boolean()->optional(),
            'tags' => Z::array(Z::string()->trim()->min(1)->max(80))->max(20)->optional(),
            'audio_duration_sec' => Z::number()->int()->min(0)->max(24 * 3600)->nullable()->optional(),
            // Time-synced lyrics in .lrc format ("[mm:ss.xx] line"), typed, uploaded or made in the app.
            'lrc' => Z::union([
                Z::string()->max(200000, 'TOO_LONG')->regex('/\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\]/', 'INVALID_LRC'),
                Z::literal(''),
                Z::null(),
            ])->optional()->transform(fn ($v) => $v === '' ? null : $v),
            'youtube_url' => Z::union([
                Z::string()->trim()->max(255, 'TOO_LONG')->regex('~^https://(www\.|m\.|music\.)?(youtube\.com/(watch\?v=|shorts/|live/|embed/)|youtu\.be/)[A-Za-z0-9_-]{6,}([?&#][^\s<>"]*)?$~', 'INVALID_YOUTUBE_URL'),
                Z::literal(''),
                Z::null(),
            ])->optional()->transform(fn ($v) => $v === '' ? null : $v),
        ]);
    }

    public static function mezmurUpdate(): ZObject
    {
        return self::mezmurCreate()->partial()->strict();
    }

    public static function mezmurListQuery(): ZObject
    {
        return Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
            'category_id' => Z::coerceNumber()->int()->positive()->optional(),
            'include_subcategories' => V::bool()->optional(),
            'tag' => Z::string()->trim()->max(80)->optional(),
            'featured' => V::bool()->optional(),
            'has_audio' => V::bool()->optional(),
            'sort' => Z::enum(['recent', 'popular', 'title', 'relevance'])->optional(),
            'status' => Z::enum(['draft', 'published', 'archived'])->optional(),
            'log' => V::bool()->optional(),
        ]);
    }

    public static function mezmurChanges(): ZObject
    {
        return Z::object(['held' => Z::array(Z::object(['id' => V::id(), 'content_version' => Z::number()->int()->min(0)]))->max(2000)]);
    }
}
