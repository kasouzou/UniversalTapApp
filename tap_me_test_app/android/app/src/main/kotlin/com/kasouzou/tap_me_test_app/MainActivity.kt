package com.kasouzou.tap_me_test_app

import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    private var counter = 0
    private lateinit var counterText: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        counterText = findViewById(R.id.counterText)
        val btnTapMe: Button = findViewById(R.id.btnTapMe)
        val btnReset: Button = findViewById(R.id.btnReset)

        btnTapMe.setOnClickListener { view ->
            val button = view as Button
            
            // すでに[Pressed]状態なら何もしない
            if (button.text == "[Pressed]") return@setOnClickListener

            // ボタンを[Pressed]にし、無効化する（ターゲット単語を画面から消す）
            button.text = "[Pressed]"
            button.isEnabled = false
            
            // カウンターを更新し、トーストでフィードバック
            counter++
            counterText.text = "Total Taps: $counter"
            Toast.makeText(this, "Success: Target word tapped!", Toast.LENGTH_SHORT).show()
            
            // リセットボタンを表示する
            btnReset.visibility = View.VISIBLE
        }

        btnReset.setOnClickListener {
            // ボタンを元の状態に戻す
            btnTapMe.text = "TapMe"
            btnTapMe.isEnabled = true
            
            // リセットボタン自体は隠す
            btnReset.visibility = View.GONE
        }
    }
}
