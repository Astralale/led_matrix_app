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

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define ALERT_CHAR_UUID     "beb5483e-36e1-4688-b7f5-ea07361b26a9"

Adafruit_NeoPixel stripTop(NUM_LEDS, PIN_TOP, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel stripBot(NUM_LEDS, PIN_BOT, NEO_GRB + NEO_KHZ800);

uint8_t brightness = 100;

struct RGB {
    uint8_t r, g, b;
};

const RGB PALETTE[64] = {
        {0,   0,   0},       // 0

        {255, 0,   0},     // 1
        {255, 23,  68},   // 2
        {213, 0,   0},     // 3
        {255, 82,  82},   // 4
        {255, 64,  129},  // 5
        {245, 0,   87},    // 6
        {197, 17,  98},   // 7

        {255, 109, 0},   // 8
        {255, 143, 0},   // 9
        {255, 160, 0},   // 10
        {255, 193, 7},   // 11
        {255, 215, 64},  // 12
        {255, 234, 0},   // 13
        {255, 255, 0},   // 14
        {255, 241, 118}, // 15

        {178, 255, 89},  // 16
        {118, 255, 3},   // 17
        {100, 221, 23},  // 18
        {0,   230, 118},   // 19
        {0,   200, 83},    // 20
        {0,   255, 0},     // 21
        {105, 240, 174}, // 22
        {0,   255, 176},   // 23

        {0,   255, 255},   // 24
        {24,  255, 255},  // 25
        {0,   229, 255},   // 26
        {0,   184, 212},   // 27
        {0,   172, 193},   // 28
        {38,  198, 218},  // 29
        {77,  208, 225},  // 30
        {128, 222, 234}, // 31

        {64,  196, 255},  // 32
        {0,   176, 255},   // 33
        {0,   145, 234},   // 34
        {33,  150, 243},  // 35
        {30,  136, 229},  // 36
        {25,  118, 210},  // 37
        {41,  98,  255},   // 38
        {0,   0,   255},     // 39

        {124, 77,  255},  // 40
        {101, 31,  255},  // 41
        {98,  0,   234},    // 42
        {123, 31,  162},  // 43
        {142, 36,  170},  // 44
        {156, 39,  176},  // 45
        {170, 0,   255},   // 46
        {136, 0,   255},   // 47

        {255, 255, 255}, // 48
        {245, 245, 245}, // 49
        {238, 238, 238}, // 50
        {224, 224, 224}, // 51
        {189, 189, 189}, // 52
        {158, 158, 158}, // 53
        {117, 117, 117}, // 54
        {66,  66,  66},    // 55

        {255, 215, 0},   // 56
        {255, 192, 203}, // 57
        {173, 255, 47},  // 58
        {127, 255, 212}, // 59
        {135, 206, 235}, // 60
        {186, 85,  211},  // 61
        {255, 127, 80},  // 62
        {165, 42,  42},   // 63
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
        Serial.print("Chunk recu: ");
        Serial.print(len);
        Serial.print(" octets, total: ");
        Serial.println(rxIndex + len);

        for (int i = 0; i < len; i++) {
            if (rxIndex < 600) {
                rxBuffer[rxIndex++] = (uint8_t) value[i];
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
                    if (matrix[y][x] > 63) matrix[y][x] = 0;
                }
            }
            newMatrixReady = true;
            rxIndex = 0;
        } else if (rxBuffer[0] == 0xBB && rxBuffer[1] == 0x55 && rxIndex >= 3) {
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
            if (colorIndex > 63) colorIndex = 0;

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