#include "esp_camera.h"
#include "FS.h"
#include "SD_MMC.h"
#include <WiFi.h>
#include <WebServer.h>

#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

#define SIGNAL_PIN   16
#define REPONSE_PIN  13

// RTC memory : survit au redémarrage
RTC_DATA_ATTR int mode = 0;       // 0 = enregistrement, 1 = WiFi
RTC_DATA_ATTR int fileIndex = 0;

WebServer server(80);
bool isRecording = false;
File videoFile;

// ==============================
// MODE 0 : Enregistrement
// ==============================
void modeEnregistrement() {
    Serial.println("📹 MODE ENREGISTREMENT");

    pinMode(SIGNAL_PIN, INPUT);
    pinMode(REPONSE_PIN, OUTPUT);
    digitalWrite(REPONSE_PIN, LOW);

    // Init caméra
    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer   = LEDC_TIMER_0;
    config.pin_d0 = Y2_GPIO_NUM; config.pin_d1 = Y3_GPIO_NUM;
    config.pin_d2 = Y4_GPIO_NUM; config.pin_d3 = Y5_GPIO_NUM;
    config.pin_d4 = Y6_GPIO_NUM; config.pin_d5 = Y7_GPIO_NUM;
    config.pin_d6 = Y8_GPIO_NUM; config.pin_d7 = Y9_GPIO_NUM;
    config.pin_xclk     = XCLK_GPIO_NUM;
    config.pin_pclk     = PCLK_GPIO_NUM;
    config.pin_vsync    = VSYNC_GPIO_NUM;
    config.pin_href     = HREF_GPIO_NUM;
    config.pin_sccb_sda = SIOD_GPIO_NUM;
    config.pin_sccb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn     = PWDN_GPIO_NUM;
    config.pin_reset    = RESET_GPIO_NUM;
    config.xclk_freq_hz = 20000000;
    config.pixel_format = PIXFORMAT_JPEG;
    config.frame_size   = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count     = 1;
    config.fb_location  = CAMERA_FB_IN_DRAM;
    config.grab_mode    = CAMERA_GRAB_WHEN_EMPTY;

    if (esp_camera_init(&config) != ESP_OK) {
        Serial.println("❌ Camera FAILED");
        return;
    }
    Serial.println("✅ Camera OK !");

    if (!SD_MMC.begin()) {
        Serial.println("❌ SD FAILED");
        return;
    }
    Serial.println("✅ SD OK !");

    // Signal prêt
    digitalWrite(REPONSE_PIN, HIGH); delay(1000);
    digitalWrite(REPONSE_PIN, LOW);
    Serial.println("✅ Prêt - en attente signal...");
}

// ==============================
// MODE 1 : Serveur WiFi
// ==============================
void handleRoot() {
    String html = "<html><head><meta charset='UTF-8'>";
    html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
    html += "<style>body{background:#1a1a2e;color:white;font-family:Arial;text-align:center;padding:20px}";
    html += "h1{color:#e94560}a{display:block;margin:10px auto;padding:15px;width:80%;";
    html += "background:#16213e;border:2px solid #e94560;color:white;border-radius:10px;text-decoration:none}</style></head>";
    html += "<body><h1>📹 ESP32-CAM</h1>";
    html += "<p>✅ Enregistrement terminé</p>";
    html += "<a href='/files'>📁 Voir les vidéos</a>";
    html += "<a href='/record'>🔴 Nouvel enregistrement</a>";
    html += "</body></html>";
    server.send(200, "text/html", html);
}
void handleLatest() {
    File root = SD_MMC.open("/");
    File file = root.openNextFile();
    String latestName = "";
    int latestIdx = -1;

    while (file) {
        if (!file.isDirectory()) {
            String name = String(file.name());
            if (name.endsWith(".mjpeg")) {
                int underscorePos = name.indexOf("_");
                int dotPos = name.indexOf(".");
                if (underscorePos >= 0 && dotPos > underscorePos) {
                    int idx = name.substring(underscorePos + 1, dotPos).toInt();
                    if (idx > latestIdx) {
                        latestIdx = idx;
                        latestName = name;
                    }
                }
            }
        }
        file = root.openNextFile();
    }

    if (latestName == "") {
        server.send(404, "text/plain", "Aucune video");
        return;
    }

    String fullPath = "/" + latestName;
    File latest = SD_MMC.open(fullPath, FILE_READ);

    if (!latest) {
        server.send(404, "text/plain", "Fichier introuvable");
        return;
    }

    size_t fileSize = latest.size();

    server.setContentLength(fileSize);
    server.send(200, "video/x-motion-jpeg", "");

    uint8_t buf[1024];
    while (latest.available()) {
        int len = latest.read(buf, sizeof(buf));
        server.client().write(buf, len);
    }

    latest.close();
}

void handleFiles() {
    String html = "<html><head><meta charset='UTF-8'>";
    html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
    html += "<style>body{background:#1a1a2e;color:white;font-family:Arial;padding:20px}";
    html += "h1{color:#e94560;text-align:center}";
    html += ".f{display:flex;justify-content:space-between;align-items:center;";
    html += "background:#16213e;margin:10px 0;padding:15px;border-radius:10px}";
    html += "a.b{padding:8px 15px;background:#e94560;color:white;border-radius:5px;text-decoration:none;margin:2px}";
    html += "a.d{background:#555}a.back{display:block;text-align:center;margin:20px;color:#e94560}</style></head>";
    html += "<body><h1>📁 Vidéos</h1>";

    File root = SD_MMC.open("/");
    File file = root.openNextFile();
    bool hasFiles = false;

    while (file) {
        if (!file.isDirectory()) {
            String name = String(file.name());
            if (name.endsWith(".mjpeg")) {
                hasFiles = true;
                float mo = file.size() / 1048576.0;
                html += "<div class='f'><span>🎥 " + name + "<br><small>" + String(mo, 2) + " Mo</small></span>";
                html += "<div><a class='b' href='/download?f=" + name + "'>⬇️</a> ";
                html += "<a class='b d' href='/delete?f=" + name + "'>🗑️</a></div></div>";
            }
        }
        file = root.openNextFile();
    }

    if (!hasFiles) html += "<p style='text-align:center'>Aucune vidéo</p>";
    html += "<a class='back' href='/'>← Retour</a></body></html>";
    server.send(200, "text/html", html);
}

void handleDownload() {
    if (!server.hasArg("f")) { server.send(400, "text/plain", "Manquant"); return; }
    String filename = "/" + server.arg("f");
    File file = SD_MMC.open(filename, FILE_READ);
    if (!file) { server.send(404, "text/plain", "Introuvable"); return; }
    server.sendHeader("Content-Disposition", "attachment; filename=" + server.arg("f"));
    server.sendHeader("Content-Length", String(file.size()));
    server.streamFile(file, "video/x-motion-jpeg");
    file.close();
}

void handleDelete() {
    if (!server.hasArg("f")) { server.send(400, "text/plain", "Manquant"); return; }
    SD_MMC.remove("/" + server.arg("f"));
    server.sendHeader("Location", "/files");
    server.send(303);
}

void handleRecord() {
    // Bascule en mode enregistrement au prochain démarrage
    mode = 0;
    server.send(200, "text/html",
                "<html><body style='background:#1a1a2e;color:white;text-align:center;padding:40px'>"
                "<h2>🔄 Redémarrage en mode enregistrement...</h2></body></html>");
    delay(2000);
    ESP.restart();
}

void modeWiFi() {
    Serial.println("🌐 MODE WIFI");

    if (!SD_MMC.begin()) {
        Serial.println("❌ SD FAILED");
        return;
    }
    Serial.println("✅ SD OK !");

    WiFi.mode(WIFI_AP);
    WiFi.softAP("ESP32-CAM");
    Serial.println("✅ WiFi OK : " + WiFi.softAPIP().toString());

    server.on("/",        handleRoot);
    server.on("/latest", handleLatest);
    server.on("/files",   handleFiles);
    server.on("/download",handleDownload);
    server.on("/delete",  handleDelete);
    server.on("/record",  handleRecord);
    server.begin();
    Serial.println("✅ Serveur OK ! → http://192.168.4.1");
}

// ==============================
// SETUP & LOOP
// ==============================
void setup() {
    Serial.begin(115200);
    delay(2000);
    Serial.println("=== Démarrage (mode " + String(mode) + ") ===");

    if (mode == 0) {
        modeEnregistrement();
    } else {
        modeWiFi();
    }
}

void loop() {
    if (mode == 0) {
        bool signal = digitalRead(SIGNAL_PIN);

        if (signal == HIGH && !isRecording) {
            isRecording = true;
            String filename = "/video_" + String(fileIndex++) + ".mjpeg";
            videoFile = SD_MMC.open(filename, FILE_WRITE);
            if (videoFile) {
                Serial.println("▶️ " + filename);
                digitalWrite(REPONSE_PIN, HIGH); delay(100);
                digitalWrite(REPONSE_PIN, LOW);  delay(100);
                digitalWrite(REPONSE_PIN, HIGH); delay(100);
                digitalWrite(REPONSE_PIN, LOW);
            } else {
                Serial.println("❌ Erreur fichier !");
                isRecording = false;
            }
        }

        if (signal == LOW && isRecording) {
            isRecording = false;
            videoFile.close();
            Serial.println("⏹️ Terminé → passage WiFi dans 2s...");
            digitalWrite(REPONSE_PIN, HIGH); delay(500);
            digitalWrite(REPONSE_PIN, LOW);
            delay(2000);

            // Bascule en mode WiFi et redémarre
            mode = 1;
            ESP.restart();
        }

        if (isRecording && videoFile) {
            camera_fb_t *fb = esp_camera_fb_get();
            if (fb) {
                videoFile.write(fb->buf, fb->len);
                videoFile.flush();
                esp_camera_fb_return(fb);
            }
            delay(100);
        }

    } else {
        server.handleClient();
    }
}