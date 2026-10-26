<?php

namespace App\Mz\Support;

/** Borrowing validators (port of validators/borrowing.js). */
final class BorrowSchemas
{
    public static function signature()
    {
        return Z::string()->max(700000, 'SIGNATURE_TOO_LARGE')->regex('#^data:image/png;base64,#', 'INVALID_SIGNATURE');
    }

    public static function create()
    {
        return Z::object([
            'user_id' => V::id(),
            'item_id' => V::id(),
            'quantity' => Z::number()->int()->min(1)->max(1000)->default(1),
            'borrowed_on' => V::dateOnly()->optional(),
            'due_on' => V::dateOnly()->optional(),
            'loan_days' => Z::number()->int()->min(0)->max(365)->optional(),
            'notes' => V::optionalText(500),
            'signature' => self::signature()->optional(),
            // Condition when handed over (default: the item's current condition).
            'issue_condition' => V::optionalText(100),
        ])->refine(fn ($v) => ! (isset($v['due_on'], $v['borrowed_on'])) || $v['due_on'] >= $v['borrowed_on'], ['message' => 'DEADLINE_BEFORE_BORROW', 'path' => ['due_on']]);
    }

    public static function returnShape(): array
    {
        return [
            'returned_on' => V::dateOnly()->optional(),
            'returned_quantity' => Z::number()->int()->min(1)->max(1000)->optional(),
            'return_condition' => V::text(1, 100),
            'return_notes' => V::optionalText(1000),
            'fine_amount' => Z::number()->min(0, 'NEGATIVE_AMOUNT')->max(1000000)->nullable()->optional(),
            'fine_override_reason' => V::optionalText(500),
            'fine_status' => Z::enum(['none', 'pending', 'paid', 'waived'])->optional(),
        ];
    }
}
