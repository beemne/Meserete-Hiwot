package com.mezmur.zelideta.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * AppWidgetProvider for the Expanded Sinksar Home-Screen Widget (4x2 / 4x3).
 */
class SinksarExpandedWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        // Immediately render cached/local date data
        SinksarWidgetManager.updateAllWidgets(context)
        // Refresh in background if network is reachable
        SinksarWidgetManager.fetchLatestSinksarInBackground(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            SinksarWidgetManager.ACTION_REFRESH_SINKSAR -> {
                // Interactive refresh requested from the widget UI
                SinksarWidgetManager.fetchLatestSinksarInBackground(context)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON" -> {
                SinksarWidgetManager.updateAllWidgets(context)
                SinksarWidgetManager.fetchLatestSinksarInBackground(context)
            }
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        SinksarWidgetManager.updateAllWidgets(context)
    }
}
