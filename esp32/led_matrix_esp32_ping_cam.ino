#include <Adafruit_NeoPixel.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define PIN_TOP 16
#define PIN_BOT 18
#define NUM_LEDS 256
#define PIN_BUTTON 15

#define WIDTH 32
#define HEIGHT 16
#define PANEL_H 8
#define PANEL_W 32

#define SIGNAL_PIN   X   // ← remplace X : signal vers ESP32-CAM GPIO16
#define REPONSE_PIN  Y   // ← remplace Y : retour depuis ESP32-CAM GPIO13

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define ALERT_CHAR_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26a9"

Adafruit_NeoPixel stripTop(NUM_LEDS, PIN_TOP, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel stripBot(NUM_LEDS, PIN_BOT, NEO_GRB + NEO_KHZ800);

uint8_t brightness = 100;

struct RGB { uint8_t r, g, b; };

const RGB PALETTE[64] = {
        {0,0,0},{255,0,0},{255,23,68},{213,0,0},{255,82,82},{255,64,129},{245,0,87},{197,17,98},
        {255,109,0},{255,143,0},{255,160,0},{255,193,7},{255,215,64},{255,234,0},{255,255,0},{255,241,118},
        {178,255,89},{118,255,3},{100,221,23},{0,230,118},{0,200,83},{0,255,0},{105,240,174},{0,255,176},
        {0,255,255},{24,255,255},{0,229,255},{0,184,212},{0,172,193},{38,198,218},{77,208,225},{128,222,234},
        {64,196,255},{0,176,255},{0,145,234},{33,150,243},{30,136,229},{25,118,210},{41,98,255},{0,0,255},
        {124,77,255},{101,31,255},{98,0,234},{123,31,162},{142,36,170},{156,39,176},{170,0,255},{136,0,255},
        {255,255,255},{245,245,245},{238,238,238},{224,224,224},{189,189,189},{158,158,158},{117,117,117},{66,66,66},
        {255,215,0},{255,192,203},{173,255,47},{127,255,212},{135,206,235},{186,85,211},{255,127,80},{165,42,42}
};

uint8_t matrix[HEIGHT][WIDTH] = {0};
uint8_t rxBuffer[600];
int rxIndex = 0;
bool newMatrixReady = false;

BLEServer *pServer = nullptr;
BLECharacteristic *pCharacteristic = nullptr;
BLECharacteristic *pAlertCharacteristic = nullptr;
bool deviceConnected = false;

unsigned long lastButtonPress = 0;
const unsigned long debounceDelay = 500;

// état enregistrement
bool enregistrement = false;

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer *pServer) {
        deviceConnected = true;
        Serial.println("Client connecte");
    }
    void onDisconnect(BLEServer *pServer) {
        deviceConnected = false;
        Serial.println("Client deconnecte");
        rxIndex = 0;
    }
};

class CharacteristicCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue();
        int len = value.length();
        for (int i = 0; i < len; i++) {
            if (rxIndex < 600) rxBuffer[rxIndex++] = (uint8_t)value[i];
        }
        if (rxBuffer[0] == 0xAA && rxBuffer[1] == 0x55 && rxIndex >= 514) {
            for (int y = 0; y < HEIGHT; y++)
                for (int x = 0; x < WIDTH; x++) {
                    matrix[y][x] = rxBuffer[2 + y * WIDTH + x];
                    if (matrix[y][x] > 63) matrix[y][x] = 0;
                }
            newMatrixReady = true;
            rxIndex = 0;
        } else if (rxBuffer[0] == 0xBB && rxBuffer[1] == 0x55 && rxIndex >= 3) {
            brightness = rxBuffer[2];
            stripTop.setBrightness(brightness);
            stripBot.setBrightness(brightness);
            rxIndex = 0;
        }
    }
};

int panelXYToIndex(int x, int y) {
    if (x < 0 || x >= PANEL_W || y < 0 || y >= PANEL_H) return -1;
    if (x % 2 == 0) return x * PANEL_H + y;
    return x * PANEL_H + (PANEL_H - 1 - y);
}

void displayMatrix() {
    stripTop.clear(); stripBot.clear();
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            uint8_t colorIndex = matrix[y][x];
            if (colorIndex == 0 || colorIndex > 63) continue;
            RGB c = PALETTE[colorIndex];
            if (y < 8) {
                int idx = panelXYToIndex(x, y);
                if (idx >= 0) stripTop.setPixelColor(idx, stripTop.Color(c.r, c.g, c.b));
            } else {
                int idx = panelXYToIndex(x, y - 8);
                if (idx >= 0) stripBot.setPixelColor(idx, stripBot.Color(c.r, c.g, c.b));
            }
        }
    }
    stripTop.show(); stripBot.show();
}

void drawHelp() {
    int helpCoords[16][32] = {
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,1,1,1,0,0,1,1,1,0,1,1,1,1,0,0,1,1,1,1,1,0,0,0,0,0,0},
            {0,0,0,0,0,1,0,0,0,1,0,0,1,0,0,1,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,1,0,0,0,1,0,0,1,0,0,1,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,1,1,1,1,1,0,0,1,0,0,1,0,0,0,1,0,1,1,1,1,0,0,0,0,0,0,0},
            {0,0,0,0,0,1,0,0,0,1,0,0,1,0,0,1,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,1,0,0,0,1,0,0,1,0,0,1,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,1,0,0,0,1,0,1,1,1,0,1,1,1,1,0,0,1,1,1,1,1,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
            {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    };
    stripTop.clear(); stripBot.clear();
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            uint8_t colorIndex = helpCoords[y][x];
            if (colorIndex == 0) continue;
            RGB c = PALETTE[colorIndex];
            if (y < 8) {
                int idx = panelXYToIndex(x, y);
                if (idx >= 0) stripTop.setPixelColor(idx, stripTop.Color(c.r, c.g, c.b));
            } else {
                int idx = panelXYToIndex(x, y - 8);
                if (idx >= 0) stripBot.setPixelColor(idx, stripBot.Color(c.r, c.g, c.b));
            }
        }
    }
    stripTop.show(); stripBot.show();
}

void sendAlertToApp() {
    if (deviceConnected && pAlertCharacteristic != nullptr) {
        uint8_t alertData[2] = {0xCC, 0xAA};
        pAlertCharacteristic->setValue(alertData, 2);
        pAlertCharacteristic->notify();
        Serial.println(">>> ALERTE BLE ENVOYEE <<<");
    }
}

// déclenche l'enregistrement sur l'ESP32-CAM
void triggerRecording() {
    enregistrement = !enregistrement;

    if (enregistrement) {
        digitalWrite(SIGNAL_PIN, HIGH);
        Serial.println("▶️ Signal ON → ESP32-CAM");
    } else {
        digitalWrite(SIGNAL_PIN, LOW);
        Serial.println("⏹️ Signal OFF → ESP32-CAM");
    }

    // Attend réponse ESP32-CAM (timeout 3s)
    unsigned long timeout = millis();
    while (digitalRead(REPONSE_PIN) == LOW) {
        if (millis() - timeout > 3000) {
            Serial.println("❌ Pas de réponse ESP32-CAM !");
            return;
        }
        delay(10);
    }

    // Mesure durée impulsion
    unsigned long debut = millis();
    while (digitalRead(REPONSE_PIN) == HIGH) delay(10);
    unsigned long duree = millis() - debut;

    if (duree >= 400) {
        Serial.println("✅ CAM : enregistrement terminé !");
        enregistrement = false; // sync arrêt automatique 5s
    } else {
        Serial.println("✅ CAM : enregistrement démarré !");
    }
}

void setup() {
    Serial.begin(115200);
    pinMode(PIN_BUTTON, INPUT_PULLUP);

    // init pins signal
    pinMode(SIGNAL_PIN, OUTPUT);
    pinMode(REPONSE_PIN, INPUT);
    digitalWrite(SIGNAL_PIN, LOW);

    delay(1000);
    Serial.println("=== DEMARRAGE ===");

    stripTop.begin(); stripBot.begin();
    stripTop.setBrightness(brightness); stripBot.setBrightness(brightness);
    stripTop.clear(); stripBot.clear();
    stripTop.show(); stripBot.show();

    BLEDevice::init("LED_MATRIX");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    BLEService *pService = pServer->createService(BLEUUID(SERVICE_UUID), 30);

    pCharacteristic = pService->createCharacteristic(
            CHARACTERISTIC_UUID,
            BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    pCharacteristic->setCallbacks(new CharacteristicCallbacks());
    pCharacteristic->addDescriptor(new BLE2902());

    pAlertCharacteristic = pService->createCharacteristic(
            ALERT_CHAR_UUID,
            BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ
    );
    pAlertCharacteristic->addDescriptor(new BLE2902());

    pService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();

    Serial.println("LED_MATRIX BLE Ready!");
}

bool wasConnected = false;

void loop() {
    if (deviceConnected && !wasConnected) wasConnected = true;

    if (!deviceConnected && wasConnected) {
        delay(500);
        pServer->startAdvertising();
        Serial.println("Advertising redemarre");
        wasConnected = false;
    }

    if (digitalRead(PIN_BUTTON) == LOW) {
        unsigned long currentTime = millis();
        if (currentTime - lastButtonPress > debounceDelay) {
            lastButtonPress = currentTime;
            drawHelp();
            sendAlertToApp();      // ← alerte BLE inchangée
            triggerRecording();    //signal vers ESP32-CAM
            delay(2000);
        }
    } else {
        if (newMatrixReady) newMatrixReady = false;
        displayMatrix();
    }
    delay(10);
}