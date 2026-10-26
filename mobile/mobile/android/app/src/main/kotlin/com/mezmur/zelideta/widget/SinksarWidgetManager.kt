package com.mezmur.zelideta.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.mezmur.zelideta.MainActivity
import com.mezmur.zelideta.R
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Central manager for Sinksar Home-Screen Widgets.
 * Handles RemoteViews population, deep-linking, offline fallback, and background refresh.
 */
object SinksarWidgetManager {

    private const val TAG = "SinksarWidget"
    const val ACTION_REFRESH_SINKSAR = "com.mezmur.zelideta.ACTION_REFRESH_SINKSAR"
    private const val PRODUCTION_API_URL = "https://app.hersolan.pro/api/v1/sinksar/today"

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * Update all active widget instances (both compact and expanded).
     */
    fun updateAllWidgets(context: Context, data: SinksarWidgetData? = null) {
        val widgetData = data ?: SinksarWidgetData.loadFromPrefs(context)
        val appWidgetManager = AppWidgetManager.getInstance(context)

        // 1. Update Compact Widgets
        val compactComponent = ComponentName(context, SinksarCompactWidgetProvider::class.java)
        val compactIds = appWidgetManager.getAppWidgetIds(compactComponent)
        for (widgetId in compactIds) {
            val views = buildCompactRemoteViews(context, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        // 2. Update Expanded Widgets
        val expandedComponent = ComponentName(context, SinksarExpandedWidgetProvider::class.java)
        val expandedIds = appWidgetManager.getAppWidgetIds(expandedComponent)
        for (widgetId in expandedIds) {
            val views = buildExpandedRemoteViews(context, widgetData)
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        Log.d(TAG, "Updated ${compactIds.size} compact and ${expandedIds.size} expanded widgets for ${widgetData.ethiopianDate}")
    }

    /**
     * Build RemoteViews for the Compact 2x1 / 2x2 widget.
     */
    fun buildCompactRemoteViews(context: Context, data: SinksarWidgetData): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_sinksar_compact)

        // Date
        views.setTextViewText(R.id.widget_compact_date, data.formattedDate)

        // Commemoration
        val commemoration = if (data.featuredTitle.isNotBlank()) {
            data.featuredTitle
        } else if (data.annualFeasts.isNotEmpty()) {
            data.annualFeasts.first()
        } else if (data.monthlyFeasts.isNotEmpty()) {
            data.monthlyFeasts.first()
        } else {
            "የዕለቱ ስንክሳር እና መታሰቢያ"
        }
        views.setTextViewText(R.id.widget_compact_commemoration, commemoration)

        // Fasting indicator
        if (data.isFasting) {
            views.setViewVisibility(R.id.widget_compact_fasting, View.VISIBLE)
            views.setTextViewText(R.id.widget_compact_fasting, data.fastingReason ?: "የጾም ቀን")
        } else {
            views.setViewVisibility(R.id.widget_compact_fasting, View.GONE)
        }

        // Deep-link PendingIntent to Sinksar screen
        val openIntent = createOpenAppIntent(context, data.gregorianDate)
        views.setOnClickPendingIntent(R.id.widget_compact_root, openIntent)

        return views
    }

    /**
     * Build RemoteViews for the Expanded 4x2 / 4x3 widget.
     */
    fun buildExpandedRemoteViews(context: Context, data: SinksarWidgetData): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_sinksar_expanded)

        // Dates
        views.setTextViewText(R.id.widget_expanded_eth_date, data.formattedFull)

        val ethHelper = EthiopianCalendarHelper.todayInAddis()
        views.setTextViewText(R.id.widget_expanded_greg_date, ethHelper.gregorianDateFormatted)

        // Fasting indicator
        if (data.isFasting) {
            views.setViewVisibility(R.id.widget_expanded_fasting, View.VISIBLE)
            views.setTextViewText(R.id.widget_expanded_fasting, data.fastingReason ?: "የጾም ቀን")
        } else {
            views.setViewVisibility(R.id.widget_expanded_fasting, View.GONE)
        }

        // Annual Feasts
        if (data.annualFeasts.isNotEmpty()) {
            views.setViewVisibility(R.id.widget_expanded_annual_feasts, View.VISIBLE)
            views.setTextViewText(R.id.widget_expanded_annual_feasts, data.annualFeastsFormatted)
        } else {
            views.setViewVisibility(R.id.widget_expanded_annual_feasts, View.GONE)
        }

        // Monthly Feasts
        if (data.monthlyFeasts.isNotEmpty()) {
            views.setViewVisibility(R.id.widget_expanded_monthly_feasts, View.VISIBLE)
            views.setTextViewText(R.id.widget_expanded_monthly_feasts, data.monthlyFeastsFormatted)
        } else {
            views.setViewVisibility(R.id.widget_expanded_monthly_feasts, View.GONE)
        }

        // Summary / Description
        views.setTextViewText(R.id.widget_expanded_summary, data.displaySummary)

        // Last updated & status
        val updatedText = data.lastUpdatedDisplay
        if (updatedText.isNotBlank()) {
            views.setViewVisibility(R.id.widget_expanded_updated, View.VISIBLE)
            views.setTextViewText(R.id.widget_expanded_updated, updatedText)
        } else {
            views.setViewVisibility(R.id.widget_expanded_updated, View.GONE)
        }

        // Deep-link to Sinksar screen on card click
        val openIntent = createOpenAppIntent(context, data.gregorianDate)
        views.setOnClickPendingIntent(R.id.widget_expanded_root, openIntent)

        // Refresh action PendingIntent on refresh button
        val refreshIntent = Intent(context, SinksarExpandedWidgetProvider::class.java).apply {
            action = ACTION_REFRESH_SINKSAR
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context,
            2002,
            refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_btn_refresh, refreshPendingIntent)

        return views
    }

    /**
     * Create PendingIntent to launch the app and open Sinksar for the target date.
     */
    private fun createOpenAppIntent(context: Context, gregorianDate: String): PendingIntent {
        val targetDate = gregorianDate.ifEmpty {
            EthiopianCalendarHelper.todayInAddis().gregorianDateIso
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("mezmurzelideta://open/sinksar/$targetDate")
            putExtra("payload", "sinksar:$targetDate")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        return PendingIntent.getActivity(
            context,
            targetDate.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * Perform an asynchronous background fetch of today's Sinksar data from production API.
     */
    fun fetchLatestSinksarInBackground(context: Context, onComplete: ((Boolean) -> Unit)? = null) {
        executor.execute {
            var success = false
            try {
                val url = URL(PRODUCTION_API_URL)
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = 6000
                    readTimeout = 6000
                    setRequestProperty("Accept", "application/json")
                    setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 14; Mobile) MezmurZelideta/1.5.3")
                }

                if (conn.responseCode == HttpURLConnection.HTTP_OK) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream))
                    val response = reader.readText()
                    reader.close()

                    val json = JSONObject(response)
                    val data = SinksarWidgetData.fromJson(json, isOffline = false)
                    data.saveToPrefs(context)

                    mainHandler.post {
                        updateAllWidgets(context, data)
                        onComplete?.invoke(true)
                    }
                    success = true
                }
            } catch (e: Exception) {
                Log.w(TAG, "Background Sinksar fetch failed: ${e.message}")
            }

            if (!success) {
                // Network unavailable or server error: load cached data or local fallback and mark offline
                mainHandler.post {
                    val cached = SinksarWidgetData.loadFromPrefs(context)
                    val offlineData = cached.copy(isOffline = true, lastUpdatedMillis = System.currentTimeMillis())
                    offlineData.saveToPrefs(context)
                    updateAllWidgets(context, offlineData)
                    onComplete?.invoke(false)
                }
            }
        }
    }
}
