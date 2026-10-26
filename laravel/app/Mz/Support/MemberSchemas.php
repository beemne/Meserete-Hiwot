<?php

namespace App\Mz\Support;

/** Member classification and the membership form (port of validators/members.js). */
final class MemberSchemas
{
    public const MEMBER_GROUPS = ['children', 'youth_adult', 'married'];
    public const MEMBERSHIP_STATUSES = ['active', 'deceased', 'inactive', 'university', 'abroad'];

    private static function shortPhone(): ZType
    {
        return Z::string()->trim()->max(30)->nullable()->optional();
    }

    /** @return array<string,ZType> sections 1-13 of the membership form */
    public static function profileShape(): array
    {
        $t = fn (int $max) => V::optionalText($max);
        $d = fn () => V::dateOnly()->nullable()->optional();
        $e = fn (array $v) => Z::enum($v)->nullable()->optional();
        return [
            'gender' => $e(['male', 'female']),
            'mother_name' => $t(150),
            'birth_date' => $d(),
            'birth_diocese' => $t(100),
            'birth_city' => $t(100),
            'birth_woreda' => $t(60),
            'birth_kebele' => $t(60),
            'birth_place_name' => $t(100),
            'christian_name' => $t(100),
            'baptism_church' => $t(150),
            'baptism_date' => $d(),
            'address_woreda' => $t(60),
            'house_number' => $t(30),
            'phone_home' => self::shortPhone(),
            'emergency_name' => $t(150),
            'emergency_phone_home' => self::shortPhone(),
            'emergency_phone_mobile' => self::shortPhone(),
            'abinet_education' => $e(['qes', 'deacon', 'none', 'other']),
            'abinet_other' => $t(100),
            'theology_education' => $e(['masters', 'degree', 'diploma', 'certificate']),
            'secular_education' => $e(['doctorate', 'masters', 'degree', 'diploma', 'certificate']),
            'institution_name' => $t(150),
            'field_of_study' => $t(150),
            'employer_type' => $e(['private', 'government']),
            'profession_id' => Z::number()->int()->positive()->nullable()->optional(),
            'profession_category' => $t(100),
            'profession' => $t(150),
            'profession_other' => $t(255),
            'experience_profession' => $t(150),
            'church_service' => $t(200),
            'school_name' => $t(150),
            'confession_father_name' => $t(150),
            'confession_father_phone' => self::shortPhone(),
            'marital_status' => $e(['married', 'single']),
            'marriage_type' => $e(['teklil', 'kurban', 'other']),
            'marriage_other' => $t(100),
        ];
    }

    public static function profile(): ZObject
    {
        return Z::object(self::profileShape())->strict();
    }

    public static function profileFields(): array
    {
        return array_keys(self::profileShape());
    }

    /** Classification an administrator sets. */
    public static function memberFields(): array
    {
        return [
            'member_group' => V::memberGroup()->optional(),
            'member_type' => Z::enum(['student', 'worker'])->nullable()->optional(),
            'can_login' => Z::boolean()->optional(),
            'membership_status' => Z::enum(self::MEMBERSHIP_STATUSES)->optional(),
            'membership_status_date' => V::dateOnly()->nullable()->optional(),
            'membership_status_detail' => V::optionalText(150),
            'spiritual_level' => Z::number()->int()->min(1)->max(12)->nullable()->optional(),
            'profile' => self::profile()->optional(),
        ];
    }
}
