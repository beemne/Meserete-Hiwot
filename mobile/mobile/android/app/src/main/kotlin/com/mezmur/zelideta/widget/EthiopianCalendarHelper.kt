package com.mezmur.zelideta.widget

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Pure Kotlin Ethiopian Calendar converter (Amete Mihret) based on Julian Day Number.
 * Operates strictly in Africa/Addis_Ababa timezone.
 */
object EthiopianCalendarHelper {

    private val ADDIS_TZ: TimeZone = TimeZone.getTimeZone("Africa/Addis_Ababa")

    val MONTHS_AM = arrayOf(
        "", "መስከረም", "ጥቅምት", "ኅዳር", "ታኅሣሥ", "ጥር", "የካቲት",
        "መጋቢት", "ሚያዝያ", "ግንቦት", "ሰኔ", "ሐምሌ", "ነሐሴ", "ጳጉሜ"
    )

    // Calendar.DAY_OF_WEEK: 1=SUNDAY, 2=MONDAY, ... 7=SATURDAY
    val WEEKDAYS_AM = arrayOf("", "እሑድ", "ሰኞ", "ማክሰኞ", "ረቡዕ", "ሐሙስ", "ዓርብ", "ቅዳሜ")
    val WEEKDAYS_EN = arrayOf("", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")

    // Canonical monthly feast associations (days 1 to 30)
    val MONTHLY_FEASTS = mapOf(
        1 to "ልደታ ለማርያም፣ ኤልያስ ነቢይ",
        2 to "ታዴዎስ ሐዋርያ",
        3 to "በዓለ ዜና ማርቆስ",
        4 to "ዮሐንስ ወልደ ነጎድጓድ",
        5 to "አቡነ ገብረ መንፈስ ቅዱስ (ጴጥሮስ ወጳውሎስ)",
        6 to "ደብረ ቁስቋም (ማርያም በስደት)",
        7 to "በዓለ ሥላሴ (አብ፣ ወልድ፣ መንፈስ ቅዱስ)",
        8 to "አባ ኪሮስ",
        9 to "ቶማስ ሐዋርያ",
        10 to "መስቀለ ክርስቶስ",
        11 to "ሐና ወኢያቄም",
        12 to "ቅዱስ ሚካኤል ሊቀ መላእክት",
        13 to "እግዚአብሔር አብ፣ ሩፋኤል ሊቀ መላእክት",
        14 to "አቡነ አረጋዊ፣ ገብረ ክርስቶስ",
        15 to "ቅዱስ ቂርቆስና እናቱ ኢየሉጣ",
        16 to "ኪዳነ ምሕረት",
        17 to "እስጢፋኖስ ቀዳሜ ሰማዕት",
        18 to "ኤዎስጣቴዎስ",
        19 to "ቅዱስ ገብርኤል ሊቀ መላእክት",
        20 to "ሕንጸተ ቤተ ክርስቲያን (ጽንጸታ ለማርያም)",
        21 to "እግዝእትነ ማርያም (በዓለ እግዝእትነ)",
        22 to "ኡራኤል ሊቀ መላእክት፣ ደቅስዮስ",
        23 to "ቅዱስ ጊዮርጊስ ሰማዕት",
        24 to "አቡነ ተክለ ሃይማኖት",
        25 to "መርቆሬዎስ ሰማዕት",
        26 to "ቶማስ ዘደብረ ማውፃ",
        27 to "መድኃኔ ዓለም",
        28 to "አማኑኤል",
        29 to "በዓለ ወልድ (እግዚእነ ኢየሱስ ክርስቶስ)",
        30 to "ዮሐንስ መጥምቅ"
    )

    data class EthDate(
        val year: Int,
        val month: Int,
        val day: Int,
        val weekday: Int,
        val gregYear: Int,
        val gregMonth: Int,
        val gregDay: Int
    ) {
        val monthNameAm: String get() = if (month in 1..13) MONTHS_AM[month] else "ወር"
        val weekdayAm: String get() = if (weekday in 1..7) WEEKDAYS_AM[weekday] else ""
        val weekdayEn: String get() = if (weekday in 1..7) WEEKDAYS_EN[weekday] else ""

        val formattedDate: String
            get() = "$monthNameAm $day ቀን $year ዓ.ም"

        val formattedFull: String
            get() = "$monthNameAm $day ቀን $year ዓ.ም · $weekdayAm"

        val gregorianDateIso: String
            get() = String.format(Locale.US, "%04d-%02d-%02d", gregYear, gregMonth, gregDay)

        val gregorianDateFormatted: String
            get() {
                val cal = Calendar.getInstance(ADDIS_TZ)
                cal.set(gregYear, gregMonth - 1, gregDay)
                val sdf = SimpleDateFormat("MMM d, yyyy", Locale.US)
                sdf.timeZone = ADDIS_TZ
                return sdf.format(cal.time)
            }

        val isFastingDay: Boolean
            get() = weekday == Calendar.WEDNESDAY || weekday == Calendar.FRIDAY

        val monthlyCommemoration: String
            get() = MONTHLY_FEASTS[day] ?: "የዕለቱ ወርኀዊ መታሰቢያ"
    }

    private fun jdnFromGregorian(y: Int, m: Int, d: Int): Int {
        val a = (14 - m) / 12
        val yy = y + 4800 - a
        val mm = m + 12 * a - 3
        return d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045
    }

    fun fromGregorian(date: Date = Date()): EthDate {
        val cal = Calendar.getInstance(ADDIS_TZ)
        cal.time = date
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        val weekday = cal.get(Calendar.DAY_OF_WEEK)

        val jdn = jdnFromGregorian(y, m, d)
        val epoch = 1723856
        val r = (jdn - epoch) % 1461
        val n = (r % 365) + 365 * (r / 1460)
        val ethYear = 4 * ((jdn - epoch) / 1461) + r / 365 - r / 1460
        val ethMonth = n / 30 + 1
        val ethDay = n % 30 + 1

        return EthDate(
            year = ethYear,
            month = ethMonth,
            day = ethDay,
            weekday = weekday,
            gregYear = y,
            gregMonth = m,
            gregDay = d
        )
    }

    fun todayInAddis(): EthDate = fromGregorian(Date())
}
