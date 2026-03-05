#include <Adafruit_NeoPixel.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define PIN_TOP 18
#define PIN_BOT 19
#define NUM_LEDS 256
#define PIN_BUTTON 16

#define WIDTH 32
#define HEIGHT 16
#define PANEL_H 8
#define PANEL_W 32

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define ALERT_CHAR_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26a9"

Adafruit_NeoPixel stripTop(NUM_LEDS, PIN_TOP, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel stripBot(NUM_LEDS, PIN_BOT, NEO_GRB + NEO_KHZ800);

uint8_t brightness = 100;

struct RGB {
    uint8_t r, g, b;
};

const RGB PALETTE[16] = {
        { 0, 0, 0 },       // 0  - Eteint
        { 255, 0, 0 },     // 1  - Rouge
        { 0, 255, 0 },     // 2  - Vert
        { 0, 0, 255 },     // 3  - Bleu
        { 255, 255, 0 },   // 4  - Jaune
        { 255, 0, 255 },   // 5  - Magenta
        { 0, 255, 255 },   // 6  - Cyan
        { 255, 255, 255 }, // 7  - Blanc
        { 255, 136, 0 },   // 8  - Orange
        { 136, 0, 255 },   // 9  - Violet
        { 255, 20, 147 },  // 10 - Rose
        { 255, 68, 0 },    // 11 - Rouge-orange
        { 128, 255, 0 },   // 12 - Vert lime
        { 0, 170, 255 },   // 13 - Bleu ciel
        { 255, 215, 0 },   // 14 - Or
        { 0, 255, 176 },   // 15 - Turquoise
};

uint8_t matrix[HEIGHT][WIDTH] = {0};

uint8_t rxBuffer[600];
int rxIndex = 0;
bool newMatrixReady = false;

BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
BLECharacteristic* pAlertCharacteristic = nullptr;
bool deviceConnected = false;

unsigned long lastButtonPress = 0;
const unsigned long debounceDelay = 500;

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Client connecte");
    }

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("Client deconnecte");
        rxIndex = 0;
    }
};

class CharacteristicCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        String value = pCharacteristic->getValue();
        int len = value.length();
        Serial.print("Chunk recu: ");
        Serial.print(len);
        Serial.print(" octets, total: ");
        Serial.println(rxIndex + len);

        for (int i = 0; i < len; i++) {
            if (rxIndex < 600) {
                rxBuffer[rxIndex++] = (uint8_t)value[i];
            }
        }

        Serial.print("Header: 0x");
        Serial.print(rxBuffer[0], HEX);
        Serial.print(" 0x");
        Serial.println(rxBuffer[1], HEX);

        if (rxBuffer[0] == 0xAA && rxBuffer[1] == 0x55 && rxIndex >= 514) {
            Serial.println("*** MATRICE COMPLETE ***");
            for (int y = 0; y < HEIGHT; y++) {
                for (int x = 0; x < WIDTH; x++) {
                    matrix[y][x] = rxBuffer[2 + y * WIDTH + x];
                    if (matrix[y][x] > 15) matrix[y][x] = 0;
                }
            }
            newMatrixReady = true;
            rxIndex = 0;
        }
        else if (rxBuffer[0] == 0xBB && rxBuffer[1] == 0x55 && rxIndex >= 3) {
            brightness = rxBuffer[2];
            stripTop.setBrightness(brightness);
            stripBot.setBrightness(brightness);
            Serial.print("Luminosite: ");
            Serial.println(brightness);
            rxIndex = 0;
        }
    }
};

int panelXYToIndex(int x, int y) {
    if (x < 0 || x >= PANEL_W || y < 0 || y >= PANEL_H) return -1;
    if (x % 2 == 0) return x * PANEL_H + y;
    return x * PANEL_H + (PANEL_H - 1 - y);
}

void printMatrixToConsole() {
    Serial.println("=== MATRICE 32x16 ===");
    for (int y = 0; y < HEIGHT; y++) {
        Serial.print("L");
        if (y < 10) Serial.print("0");
        Serial.print(y);
        Serial.print(": ");
        for (int x = 0; x < WIDTH; x++) {
            Serial.print(matrix[y][x]);
        }
        Serial.println();
    }
    Serial.println("=====================");
}

void displayMatrix() {
    stripTop.clear();
    stripBot.clear();

    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            uint8_t colorIndex = matrix[y][x];
            if (colorIndex == 0) continue;
            if (colorIndex > 15) colorIndex = 0;

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

    stripTop.show();
    stripBot.show();
}

void drawHelp() {
    int helpCoords[16][32] = {
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    };

    stripTop.clear();
    stripBot.clear();

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

    stripTop.show();
    stripBot.show();
}

// ============================================================================
// NOUVEAU : Envoyer alerte BLE à l'app Flutter
// ============================================================================
void sendAlertToApp() {
    if (deviceConnected && pAlertCharacteristic != nullptr) {
        uint8_t alertData[2] = {0xCC, 0xAA};  // Code alerte
        pAlertCharacteristic->setValue(alertData, 2);
        pAlertCharacteristic->notify();
        Serial.println(">>> ALERTE BLE ENVOYEE A L'APP <<<");
    } else {
        Serial.println(">>> PAS DE CLIENT CONNECTE, ALERTE NON ENVOYEE <<<");
    }
}

void setup() {
    Serial.begin(115200);
    pinMode(PIN_BUTTON, INPUT_PULLUP);
    delay(1000);
    Serial.println("\n\n=== DEMARRAGE ===");

    stripTop.begin();
    stripBot.begin();
    stripTop.setBrightness(brightness);
    stripBot.setBrightness(brightness);
    stripTop.clear();
    stripBot.clear();
    stripTop.show();
    stripBot.show();

    BLEDevice::init("LED_MATRIX");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    BLEService* pService = pServer->createService(BLEUUID(SERVICE_UUID), 30);

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

    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();

    Serial.println("LED_MATRIX BLE Ready!");
    Serial.println("Alert characteristic UUID: ");
    Serial.println(ALERT_CHAR_UUID);
    Serial.println("En attente de connexion...");
}

bool wasConnected = false;

void loop() {
    if (deviceConnected && !wasConnected) {
        wasConnected = true;
    }

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
            sendAlertToApp();
            delay(2000);
        }
    } else {
        if (newMatrixReady) {
            newMatrixReady = false;
        }
        displayMatrix();
    }
    delay(10);
}