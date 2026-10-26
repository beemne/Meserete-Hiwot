<?php

namespace App\Mz\Services;

use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/** "Who did it" without revealing the internal system authority (port of actorService.js). */
final class Actor
{
    /** SQL select expression: the actor's name, or a neutral "System" label for hidden roles. */
    public static function hiddenName(string $userAlias, string $roleAlias, string $as)
    {
        return DB::raw(sprintf('CASE WHEN %s.is_hidden = 1 THEN %s ELSE %s.full_name END AS `%s`', $roleAlias, DB::getPdo()->quote(T::t('system.name')), $userAlias, $as));
    }

    public static function hiddenId(string $userAlias, string $roleAlias, string $as)
    {
        return DB::raw(sprintf('CASE WHEN %s.is_hidden = 1 THEN NULL ELSE %s.id END AS `%s`', $roleAlias, $userAlias, $as));
    }
}
