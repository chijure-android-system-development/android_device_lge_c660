# CM7 para LG-C660 (Optimus Pro / muscat)

Device tree para CyanogenMod 7 (Gingerbread) en el LG-C660, forkeado desde el
árbol oficial [CyanogenMod/android_device_lge_c660](https://github.com/CyanogenMod/android_device_lge_c660)
(rama `gingerbread`) y ajustado para compilar limpio en un árbol CM7 moderno
(mismo árbol usado para el bring-up del Huawei Y210).

Plataforma Qualcomm MSM7x27a / MSM7K, misma familia que el Y210.

## Compilación

```bash
source build/envsetup.sh
breakfast c660
mka bacon -j$(nproc)
```

Lunch combo registrado vía `vendorsetup.sh` → `cyanogen_c660-eng` /
`cyanogen_c660-userdebug` (producto real: `vendor/cyanogen/products/cyanogen_c660.mk`,
copiado a este directorio como `cyanogen_c660.mk` para que `AndroidProducts.mk`
lo registre, mismo patrón que usa `device/huawei/y210`).

## Cambios respecto al árbol oficial de CyanogenMod

- **`TARGET_PROVIDES_LIBRIL`**: estaba en `true` pero sin blob real de
  `libril.so` en el árbol → build rota (`No rule to make target libril.so`).
  Se comentó temporalmente, y se reactivó una vez extraídos los blobs reales
  del equipo (ver abajo).
- **Cámara**: `device/lge/c660/include/camera/CameraHardwareInterface.h` agrega
  dos métodos puros (`getShutterSound`, `encodeData`) pensados para un HAL CAF
  real que este manifest no trae completo. Durante el bring-up inicial (antes
  de extraer los blobs reales, con `USE_CAMERA_STUB := true`) se necesitaron
  implementaciones vacías temporales en el `CameraHardwareStub.h` compartido de
  `frameworks/base` para poder linkear. Una vez extraídos los blobs y con
  `BoardConfigVendor.mk` forzando `USE_CAMERA_STUB := false`, ese bloque de
  `frameworks/base/services/camera/libcameraservice/Android.mk` ni se compila
  — el parche a `frameworks/base` quedó sin uso y **se revirtió** (no tiene
  sentido tocar código compartido por todos los dispositivos del árbol para
  algo que ya no hace falta).
- **Kernel propio compilado desde fuente** (ver sección Kernel abajo) para
  arreglar el teclado QWERTY físico, que el kernel prebuilt del árbol oficial
  traía deshabilitado.

## Kernel

El device tree trae `kernel` prebuilt, pero ese binario (compilado ~2012 por
la comunidad) tiene el teclado físico QWERTY deshabilitado a nivel de kernel:

```
GPIO Matrix Keypad Driver: Start keypad matrix for default_keypad in interrupt mode
project isn't support qwerty
```

No se encontró ese gate en el código fuente actual de
[CyanogenMod/lge-kernel-msm7x27](https://github.com/CyanogenMod/lge-kernel-msm7x27)
(rama `android-msm-2.6.35`, coincide con la versión `2.6.35.10` corriendo en
el equipo) — probablemente viene de una revisión más vieja o del drop GPL de
LGE directo, y se corrigió/quedó afuera en el fork de CM con el tiempo. El
defconfig `arch/arm/configs/cyanogenmod_muscat_defconfig` ya trae
`CONFIG_KEYBOARD_PP2106=y`.

Se compiló un `zImage` propio desde esa fuente con el toolchain ya incluido en
este árbol:

```bash
cd kernel-c660-src   # clon de lge-kernel-msm7x27, rama android-msm-2.6.35
export ARCH=arm
export CROSS_COMPILE=<ruta-a>/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-
make cyanogenmod_muscat_defconfig
make -j$(nproc) zImage
cp arch/arm/boot/zImage device/lge/c660/kernel
```

Confirmado en equipo real: `kbd_pp2106` se registra como input device y llegan
eventos reales de tecla (`getevent`) al deslizar el teclado. El binario
original queda como referencia en `device/lge/c660/kernel.bak-original`.

## Blobs propietarios (`vendor/lge/c660`)

Extraídos con `extract-files.sh` + `setup-makefiles.sh` desde un LG-C660h real
corriendo stock `LGE/lge_muscat/muscat:2.3.4/GRJ22/V10a-Aug-23-2011.2ED2FC1835`.

También existe un repo comunitario con estos blobs ya extraídos:
[TheMuppets/proprietary_vendor_lge](https://github.com/TheMuppets/proprietary_vendor_lge/tree/gingerbread/c660)
(rama `gingerbread`, carpeta `c660`) — útil para forkear este device tree sin
tener el equipo físico a mano. Se usó para cruzar validar los dos puntos de
abajo:

- Su `c660-vendor-blobs.mk` también espera el WiFi en `proprietary/etc/wl/`,
  confirmando que el bug de `extract-files.sh` es real (no un error nuestro).
- Ellos sí traen el `BCM43291A0_003.001.013.0141.0153.hcd` de Bluetooth — existe
  en otras unidades/lotes de C660, pero no en la usada para este bring-up
  (`V10a-Aug-23-2011`). Bluetooth funciona en runtime sin ese archivo, así que
  no hizo falta traerlo.

Bugs del script oficial encontrados al extraer contra un equipo real:

- `extract-files.sh` baja el firmware WiFi (`rtecdc.bin`, `rtecdc-apsta.bin`) a
  `proprietary/etc/firmware/`, pero el `c660-vendor-blobs.mk` que genera
  `setup-makefiles.sh` los espera en `proprietary/etc/wl/`. Hay que mover los
  archivos a mano tras extraer.
- El firmware Bluetooth genérico que pide el script
  (`BCM43291A0_003.001.013.0141.0153.hcd`) **no existe** en este equipo, y
  `brcm_patchram_plus` sigue adelante igual sin él. Bluetooth levanta bien en
  runtime (`hci0` UP, BlueZ registrando servicios, pairing/A2DP validados) sin
  ese firmware. `btld` (loader propio de LG, alternativa a `brcm_patchram_plus`)
  se extrajo en su momento pero nunca se enganchó en ningún `.rc`/script — se
  quitó del build (`c660-vendor-blobs.mk`) y del equipo: no resolvía ningún
  problema real y arriesgaba romper un Bluetooth que ya funciona.

### Pendiente

- 🔴 **PRIORITARIO — Preview de cámara con color incorrecto.** No es
  cosmético: al apuntar a personas, la piel sale con un tono azulado/pálido
  (efecto "Avatar") — rompe el caso de uso más común de la cámara, aunque
  la foto final guardada sea correcta. Sigue sin fix confirmado, pero
  **queda una vía real sin probar**: parchar directamente el binario del
  blob (`libcamera.so`, con Ghidra/IDA) en la función interna que hace la
  conversión YUV→RGB para el `SurfaceView` — ya sabemos que esa conversión
  tiene los canales Cb/Cr invertidos (ver abajo) y que es un problema
  autocontenido dentro del blob, no del framework ni del kernel. Es la
  única vía que no se intentó todavía. Investigación previa (por si se
  retoma):
  - La foto capturada (JPEG real) sale con el color correcto; el bug es
    exclusivo del preview en pantalla. Causa raíz completa:
  - El SurfaceView del preview llega a SurfaceFlinger ya en RGBA — la
    conversión YUV→RGB la hace el blob (`libcamera.so`) internamente, no
    nuestro código, y esa conversión interna tiene los canales Cb/Cr
    invertidos.
  - El blob soporta el overlay de hardware (MDP), el camino correcto de
    Qualcomm para esto (`useOverlay()`/`setOverlay()` en su vtable), pero
    `useOverlay()` devuelve `false` hardcodeado (confirmado con un log de
    diagnóstico en tiempo de ejecución).
  - Se construyó un wrapper (`device/lge/c660/libcamera/`, patrón idéntico a
    `device/huawei/y210/libcamera/`) que fuerza `useOverlay()=true` por
    delegación normal de C++ (sin hackear vtable, a diferencia del wrapper
    del Y210 — el vtable del blob del C660 ya coincide con el header). Esto
    sí activó el código de overlay de `CameraService.cpp` (que ya existía sin
    usar, solo hacía falta `BOARD_OVERLAY_FORMAT_YCrCb_420_SP := true` en
    `BoardConfig.mk`), y el blob's `setOverlay()` real se llegó a invocar —
    pero falló en la capa de **kernel**: `/dev/msm_rotator` no existe en este
    build (`Cant open rotator device` / `Failed to start control channel for
    framebuffer 0`, sin crashear, solo reintentando 50 veces y fallando).
  - El código fuente del driver existe (`kernel-c660-src/drivers/char/msm_rotator.c`)
    pero **no puede habilitarse ni recompilando**: su `Kconfig` (`drivers/char/Kconfig:1153`)
    exige `depends on (ARCH_MSM7X30 || ARCH_MSM8X60)`, y este kernel es
    `ARCH_MSM7X27` — la dependencia nunca se cumple, así que Kconfig descarta
    la opción sin importar qué se escriba a mano en el defconfig. El driver
    fue escrito para un bloque de hardware de rotación distinto (revisión de
    silicio MSM7x30/8x60), no el del MSM7227A del C660. **Camino cerrado de
    forma definitiva, no es una decisión de riesgo.**
  - Se investigó también si la app de Cámara **stock** de LG (`com.lge.camera`,
    extraída de un nandroid backup real pre-CM7) resuelve el color distinto.
    Se confirmó con `md5sum` que usa el mismo `libcamera.so`/`liboemcamera.so`
    (idénticos a los nuestros) y que el kernel stock **también** carece de
    `msm_rotator` (mismos síntomas de overlay fallido esperables). Se
    descompiló el `.odex` con `dexdump`/`apktool` — el `.apk` stock no trae
    ningún `classes.dex` embebido, todo el código vive solo en el `.odex`,
    con offsets de campo "quick" horneados contra el framework.jar stock de
    LG. Al instalarlo directo sobre CM7 (mismo blob, mismo hardware) crasheó
    al instante (`SIGSEGV`/`deadbaad` en `dlfree`, corrupción de heap por
    incompatibilidad de ABI) — confirma que no es solo una diferencia de
    parámetros de cámara, la app entera está atada al framework exacto de
    LG. Un des-odex contra el framework stock (también disponible en el
    mismo dump) podría producir un `classes.dex` portable para probar, pero
    se descartó seguir por esta vía — decisión explícita del usuario.
  - Se evaluó reemplazar el blob por el `QualcommCameraHardware.cpp` de
    código abierto que traen otros device trees hermanos de LG Optimus
    (`android_device_lge_p350`/`p500`, sensor OV5642). El sensor real del
    C660 es **MT9T113** (`CONFIG_MT9T113=y` en el defconfig) — no coincide,
    y esos archivos no tienen ninguna referencia a ese sensor. Se encontró
    un mirror más genérico de Code Aurora Forum (`dzo/hardware_qcom_camera`,
    2011) con la misma cadena de log `"Resetting mUseOverlay to false"` que
    aparece en nuestro blob — ahí ese mensaje sale de `setStrTextures()`
    cuando el parámetro de cámara `"strtextures"` se pone en `"on"` — pero
    ese archivo tampoco implementa `useOverlay()`/`setOverlay()` reales, así
    que no hay garantía de que aplique a nuestro blob. Se probó forzar
    `strtextures=off` explícitamente vía `setParameters()` justo después de
    crear el delegado (antes de que `CameraService.Client` preguntara
    `useOverlay()`) con un wrapper temporal: **resultado negativo concreto**
    — la app de Cámara crashea después con `setPreviewDisplay failed`. El
    blob sí reacciona a ese parámetro, pero para peor. Revertido por
    completo (wrapper temporal eliminado, nunca comiteado).
  - **Intento final: reemplazar el glue userspace por
    `QualcommCameraHardware.cpp` de código abierto (CAF/Ricardo Cerqueira,
    via `android_device_lge_p500`), manteniendo nuestro `liboemcamera.so`
    real como motor de bajo nivel — pensado también como base reusable para
    un futuro port a CM9/ICS (ver más abajo). Compiló limpio contra nuestro
    árbol (solo hubo que agregar `getShutterSound()`/`encodeData()` como
    no-ops, exigidos por nuestro `CameraHardwareInterface.h`). Los símbolos
    "core" coinciden con nuestro blob (`mm_camera_init`, `cam_frame`,
    `jpeg_encoder_*`, `cam_conf`) — pero al probarlo en hardware real,
    **crasheó `mediaserver`** (`SIGSEGV` en dirección `0x0`) dentro de
    `startCamera()`, escribiendo a través de un puntero de
    `dlsym(liboemcamera.so, "mmcamera_camframe_callback")` que devuelve
    `NULL`. Confirmado con `nm -D`: nuestro `liboemcamera.so` **no exporta**
    `mmcamera_camframe_callback` ni `mmcamera_jpegfragment_callback` ni
    `mmcamera_jpeg_callback` ni `camframe_timeout_callback` ni
    `mmcamera_camframe_videocallback` (solo `mmcamera_shutter_callback`
    existe de ese grupo) — en cambio expone un esquema de hilos
    (`camframe_fb_thread`/`launch_camframe_fb_thread`) que esta versión del
    código no usa. Es una generación/fork del motor de cámara real
    (`liboemcamera.so`) distinta a la que asume el código de p500 para el
    mecanismo de entrega de frames — no es un ajuste chico, haría falta
    reversear el ABI real de callbacks de este blob específico sin ninguna
    referencia conocida. **Revertido por completo** (fuente descartada,
    `.mk` restaurado, verificado en equipo real que la cámara volvió a
    funcionar sin crashes).
  - **Nota para un futuro port a CM9/ICS:** este intento no fue en vano —
    ICS cambia la arquitectura de `CameraHardwareInterface` (reemplaza el
    mecanismo de overlay por uno basado en `SurfaceTexture`), así que el
    blob cerrado actual, compilado contra el ABI de Gingerbread, casi
    seguro **no cargará tal cual** contra un `CameraService` de ICS sin una
    capa nueva de todos modos — con o sin el bug de color de hoy resuelto.
    El camino real para tener cámara en CM9 sigue siendo adaptar un HAL de
    código abierto, pero **haciendo el reverse-engineering real del ABI de
    callbacks de nuestro `liboemcamera.so`** antes de portar cualquier
    fuente ajena (con herramientas como IDA/Ghidra sobre el blob, no
    asumiendo que coincide con otro device tree por los nombres de función
    "core"). Los ioctls base del kernel sí coinciden entre versiones CAF
    (ver más abajo), así que esa parte de la investigación de hoy sigue
    siendo válida.
- **Chargermode (`sbin/chargerlogo`) parpadea/tiembla visualmente al cargar
  con el equipo apagado — investigado, sin fix viable por ahora.** Disparado
  desde `init.muscat.rc` (`on boot-pause` → `exec sbin/chargerlogo`) cuando el
  kernel arranca con `lge.reboot=pwroff` en el cmdline (carga sin botón de
  power). Verificado con un nandroid backup real (CWM) que el binario
  `sbin/chargerlogo` es **byte a byte idéntico** al de nuestro árbol — no hay
  corrupción ni modificación de nuestro lado. El framebuffer sí tiene doble
  buffer real a nivel kernel (`/sys/class/graphics/fb0/virtual_size` =
  `240,640` para una pantalla de 320 de alto). El flag `BOARD_HAS_JANKY_BACKBUFFER`
  ya existente en `BoardConfig.mk` es un fix de **stride** para `minui`
  (recovery), no de timing de doble buffer, y no aplica a `chargerlogo` (no
  comparten código). El panel usa interfaz **EBI2** (bus de pantalla más
  viejo, conocido por quirks de timing en volteo de buffers en esta
  generación de MSM7x27). Sin el código fuente de `chargerlogo` (binario
  propietario de LG), la única vía que queda es investigar el driver de
  framebuffer del kernel (`drivers/video/msm` en `kernel-c660-src`) — no
  investigado más a fondo por decisión explícita, es cosmético (solo aparece
  con el equipo apagado en modo carga).
- **SIM / red móvil sin probar** (dejado para el final a propósito): no se
  confirmó llamadas, SMS ni datos móviles reales — falta insertar SIM y no se
  sabe si el equipo está liberado (unlocked) o con lock de operador. `rild`
  sí habla con el modem real (RSSI, celdas WCDMA), pero eso no confirma que
  una SIM de otro operador vaya a ser aceptada.
- **Canales SMD de datos extra fallan al abrir** (dejado para el final a
  propósito):
  ```
  smd_pkt_open: DATA8_CNTL / DATA9_CNTL / DATA12_CNTL / DATA13_CNTL / DATA14_CNTL open failed -19
  ```
  Causa raíz confirmada: `smd_named_open_on_edge()` en
  `kernel-c660-src/arch/arm/mach-msm/smd_pkt.c:568` devuelve el error directo
  del **firmware del módem** (baseband/AMSS) — el error `-19` (`ENODEV`)
  significa que esta versión de baseband nunca registró esos canales extra en
  su tabla SMD (solo trae `DATA5/6/7_CNTL`, los primarios, que sí funcionan y
  ya sostienen llamadas/SMS/datos). No es arreglable desde el kernel/ROM;
  requeriría un baseband distinto (flashear módem es riesgo alto, fuera de
  scope). Posible impacto real: conexiones de datos concurrentes/tethering
  con múltiples PDP contexts — sin confirmar si tethering realmente falla o
  si esto es solo ruido de log sin impacto.

## Overlays

- `overlay/frameworks/base/core/res/res/values/arrays.xml`: quita "Bootloader"
  del menú de reboot avanzado de CM7 (`shutdown_reboot_options` /
  `shutdown_reboot_actions`). El C660 no tiene modo bootloader accesible desde
  ahí, igual que se hizo para `device/huawei/y210`.

## Estado funcional (validado en LG-C660h real, jul-2026)

| Función | Estado | Nota |
| --- | --- | --- |
| Arranque / launcher | Funciona | Boot limpio tras flasheo, llega a launcher sin crashes de `zygote`/`system_server`/`mediaserver`. |
| Gráficos (SurfaceFlinger) | Funciona | Compositing real confirmado (`dumpsys SurfaceFlinger` con capas de wallpaper/launcher/statusbar). |
| WiFi | Funciona | Driver `ok`, interfaz `wlan0`, MAC real detectada. Falta probar asociación a red. |
| Bluetooth | Funciona | `hci0` UP RUNNING, BlueZ registrando `hfag`/`hsag`/`opush`/`map`/`pbap`. |
| RIL / baseband | Funciona (parcial) | `rild` habla con el modem real por `/dev/smd0`, recibe RSSI/celdas. **Sin probar con SIM real** — no se sabe si el equipo está liberado. |
| Sensores | Funciona | Acelerómetro y magnetómetro con datos reales confirmados (girando el equipo, valores en vivo). |
| Cámara | Funciona | Preview y uso confirmado con blobs reales (`libqcamera`). |
| Video | Funciona | Confirmado por el usuario en equipo real. |
| FM Radio | Funciona | Audio confirmado. |
| Galería 3D | Funciona | Confirmado por el usuario en equipo real. |
| Teclado físico QWERTY | Funciona | Requirió kernel propio (ver sección Kernel); eventos de tecla reales confirmados con `getevent`. |

## Instalación

CWM 5.0.2.7 (`recovery-clockwork-5.0.2.7-c660.img`) flasheado vía `flash_image`
desde `adb shell` (root). Ese build de CWM **no soporta** `adb sideload` ni el
`/cache/recovery/command` estándar sin el prefijo `boot-recovery` como primera
línea, y su `extendedcommand` exige firma de ROM Manager (falla con
`SD Card marker not found` si se escribe a mano). Instalar el zip navegando el
menú físico de CWM (`install zip from sdcard`) es el método que funcionó.

### Entrar a modo recovery

El C660 no tiene modo bootloader/fastboot accesible (ver overlay arriba).

Por software, con el equipo encendido y `adb` autorizado:

```bash
adb reboot recovery
```

Por botones físicos, con el equipo apagado: mantener **Volumen (-) + Home +
Power** hasta que arranque.

### Entrar a modo download

Modo propietario de LG para flasheo (equivalente a Odin en Samsung), no es
fastboot. Por botones físicos, con el equipo apagado: mantener **Volumen (+) +
Atrás (Back) + Power** hasta que arranque.
