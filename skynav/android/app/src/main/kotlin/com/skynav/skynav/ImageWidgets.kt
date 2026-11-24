package com.skynav.skynav

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Görüntüsünü Flutter'ın ürettiği (HomeWidget.renderFlutterWidget) ana ekran widget'ları.
 * SkyWeatherWidget ile aynı düzen; yalnızca okunan görüntü anahtarı farklı.
 */
open class ImageWidget(private val imageKey: String, private val page: String) : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.widget_image)
            val path = widgetData.getString(imageKey, null)
            if (path != null) {
                val bmp = BitmapFactory.decodeFile(path)
                if (bmp != null) v.setImageViewBitmap(R.id.widget_image, bmp)
            }
            // Dokununca uygulama açılır ve ilgili sayfaya gider (skynav://sayfa; Dart: HomeWidget.widgetClicked)
            v.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("skynav://$page")))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}

/** Önümüzdeki saatler (4×2). */
class SkyHourlyWidget : ImageWidget("hourly_img", "home")

/** Ay: evre, doğuş/batış, sıradaki dolunay (2×2). */
class SkyMoonWidget : ImageWidget("moon_img", "sky")

/** Küçük hava: sıcaklık, en yüksek/düşük, kısa yağış notu (2×2). */
class SkyMiniWidget : ImageWidget("mini_img", "home")

/** En yakın kayak merkezi: kar kalınlığı ve yeni kar (2×2). */
class SkySkiWidget : ImageWidget("ski_img", "ski")

/** Hava kalitesi: toz-duman durumu (2×2). */
class SkyAirWidget : ImageWidget("air_img", "air")
