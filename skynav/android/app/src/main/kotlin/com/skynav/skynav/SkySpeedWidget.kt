package com.skynav.skynav

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Görüntüyü Flutter üretir (HomeWidget.renderFlutterWidget); burada yalnızca gösterilir. */
class SkySpeedWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, widgetData: SharedPreferences) {
        for (id in ids) {
            val v = RemoteViews(context.packageName, R.layout.widget_image)
            val path = widgetData.getString("speed_img", null)
            if (path != null) {
                val bmp = BitmapFactory.decodeFile(path)
                if (bmp != null) v.setImageViewBitmap(R.id.widget_image, bmp)
            }
            val open = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            v.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            manager.updateAppWidget(id, v)
        }
    }
}
