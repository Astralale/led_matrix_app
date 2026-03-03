/**
 * LED Matrix ESP32 — BLE Receiver
 *
 * Configuration matérielle :
 *   - 2 dalles WS2812B 32×8 (branchées en série sur DATA_PIN)
 *     · Dalle 1 : rangées 0-7  (256 LEDs)
 *     · Dalle 2 : rangées 8-15 (256 LEDs)
 *   - Câblage serpentin par dalle (rangées paires G→D, impaires D→G)
 *
 * Protocole BLE (depuis l'app Flutter) :
 *   Trame = [0xAA, 0x55, pixel_0, pixel_1, ..., pixel_511]  =  514 octets
 *   Chaque pixel = index couleur 0-9
 *     0=Éteint  1=Rouge    2=Vert   3=Bleu  4=Jaune
 *     5=Magenta 6=Cyan     7=Blanc  8=Orange 9=Violet
 *
 * Bibliothèques requises (Arduino Library Manager) :
 *   - FastLED  >= 3.6
 *   - ESP32 BLE Arduino (inclus dans le board package ESP32)
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <FastLED.h>

// ─── Configuration matérielle ─────────────────────────────────────────────────
#define DATA_PIN        5       // Broche données WS2812B (GPIO 5)
#define MATRIX_WIDTH    32
#define MATRIX_HEIGHT   16
#define PANEL_HEIGHT    8       // Hauteur d'une dalle (2 dalles × 8 rangées)
#define NUM_LEDS        (MATRIX_WIDTH * MATRIX_HEIGHT)  // 512
#define LED_BRIGHTNESS  60      // 0-255 — réduire pour économiser le courant

// ─── UUIDs BLE ────────────────────────────────────────────────────────────────
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define DEVICE_NAME         "LED_MATRIX"

// ─── Protocole de trame ───────────────────────────────────────────────────────
#define FRAME_SIZE    512
#define HEADER_1      0xAA
#define HEADER_2      0x55

// ─── Variables globales ───────────────────────────────────────────────────────
CRGB leds[NUM_LEDS];

uint8_t  frameBuffer[FRAME_SIZE];
uint16_t bufPos          = 0;
bool     headerReceived  = false;   // true = les 2 octets 0xAA 0x55 ont été lus
bool     waitHeader1     = true;    // attend 0xAA
volatile bool newFrameReady = false;

BLEServer* pServer        = nullptr;
bool deviceConnected      = false;
bool oldDeviceConnected   = false;

// ─── Palette de couleurs ──────────────────────────────────────────────────────
CRGB indexToColor(uint8_t idx) {
  switch (idx) {
    case 1:  return CRGB(255,   0,   0);  // Rouge
    case 2:  return CRGB(  0, 255,   0);  // Vert
    case 3:  return CRGB(  0,   0, 255);  // Bleu
    case 4:  return CRGB(255, 255,   0);  // Jaune
    case 5:  return CRGB(255,   0, 255);  // Magenta
    case 6:  return CRGB(  0, 255, 255);  // Cyan
    case 7:  return CRGB(255, 255, 255);  // Blanc
    case 8:  return CRGB(255, 136,   0);  // Orange
    case 9:  return CRGB(136,   0, 255);  // Violet
    case 10: return CRGB(255,  20, 147);  // Rose
    case 11: return CRGB(255,  68,   0);  // Rouge-orange
    case 12: return CRGB(128, 255,   0);  // Vert lime
    case 13: return CRGB(  0, 170, 255);  // Bleu ciel
    case 14: return CRGB(255, 215,   0);  // Or
    case 15: return CRGB(  0, 255, 176);  // Turquoise
    default: return CRGB(  0,   0,   0);  // Éteint
  }
}

// ─── Mapping pixel (x, y) → index LED ────────────────────────────────────────
// Câblage serpentin : rangées paires de gauche à droite,
//                     rangées impaires de droite à gauche.
int pixelToLed(int x, int y) {
  int panel  = y / PANEL_HEIGHT;                         // 0 ou 1
  int localY = y % PANEL_HEIGHT;                         // 0-7 dans la dalle
  int base   = panel * (MATRIX_WIDTH * PANEL_HEIGHT);    // offset LED de la dalle
  int idx    = (localY % 2 == 0)
               ? localY * MATRIX_WIDTH + x               // G → D
               : localY * MATRIX_WIDTH + (MATRIX_WIDTH - 1 - x); // D → G
  return base + idx;
}

// ─── Rendu de la trame sur les LEDs ──────────────────────────────────────────
void renderFrame() {
  for (int y = 0; y < MATRIX_HEIGHT; y++) {
    for (int x = 0; x < MATRIX_WIDTH; x++) {
      uint8_t ci = frameBuffer[y * MATRIX_WIDTH + x];
      leds[pixelToLed(x, y)] = indexToColor(ci);
    }
  }
  FastLED.show();
}

// ─── Callbacks BLE ────────────────────────────────────────────────────────────
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    Serial.println("[BLE] Client connecté");
  }
  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    Serial.println("[BLE] Client déconnecté");
  }
};

class RxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override {
    std::string data = pChar->getValue();

    for (size_t i = 0; i < data.size(); i++) {
      uint8_t b = (uint8_t)data[i];

      // -- Recherche de l'entête 0xAA 0x55 --
      if (waitHeader1) {
        if (b == HEADER_1) {
          waitHeader1 = false;
        }
        continue;
      }
      if (!headerReceived) {
        if (b == HEADER_2) {
          headerReceived = true;
          bufPos = 0;
        } else {
          // Entête invalide, on recommence
          waitHeader1 = true;
        }
        continue;
      }

      // -- Accumulation des données de la trame --
      frameBuffer[bufPos++] = b;
      if (bufPos >= FRAME_SIZE) {
        newFrameReady  = true;
        headerReceived = false;
        waitHeader1    = true;
        bufPos         = 0;
        Serial.println("[LED] Trame reçue — affichage");
      }
    }
  }
};

// ─── Setup ────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("[INIT] Démarrage LED Matrix ESP32");

  // FastLED
  FastLED.addLeds<WS2812B, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(LED_BRIGHTNESS);
  FastLED.clear(true);

  // Animation de démarrage : balayage rouge → éteint
  for (int i = 0; i < NUM_LEDS; i++) {
    leds[i] = CRGB::Red;
    FastLED.show();
    delay(1);
  }
  FastLED.clear(true);

  // BLE
  BLEDevice::init(DEVICE_NAME);
  BLEDevice::setMTU(517);  // MTU max pour recevoir de grandes trames

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  BLECharacteristic* pChar = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_WRITE_NR   // Write Without Response (plus rapide)
  );
  pChar->setCallbacks(new RxCallbacks());

  pService->start();

  BLEAdvertising* pAdvert = BLEDevice::getAdvertising();
  pAdvert->addServiceUUID(SERVICE_UUID);
  pAdvert->setScanResponse(true);
  pAdvert->setMinPreferred(0x06);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Publicité démarrée — en attente de connexion...");
}

// ─── Loop ─────────────────────────────────────────────────────────────────────
void loop() {
  // Afficher la nouvelle trame si disponible
  if (newFrameReady) {
    newFrameReady = false;
    renderFrame();
  }

  // Redémarrer la publicité BLE après déconnexion
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("[BLE] Publicité relancée");
    oldDeviceConnected = false;
  }

  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = true;
  }
}
