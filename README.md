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
- **Bluetooth**: `patches/frameworks_base_bluetooth.patch` evita el segundo
  `StopDiscovery` cuando BlueZ ya terminó el inquiry. Sin eso, un scan que sí
  ve equipos deja `Invalid discovery session` y puede dejar la sesión colgada.
- **Logo de arranque**: `initlogo.rle` va en el ramdisk (`c660.mk`). Es el
  logo LG del `initlogo.rle` del P500 (CM7), reducido a unos 84 px de ancho,
  con «by chijure» debajo, sobre negro, a 240×320. Confirmado en el equipo.
  `patches/system_core_init_logo.patch` hace que `init` respete el stride:
  el framebuffer mide 240 px pero cada línea ocupa 512 bytes, y sin ese
  salto la imagen se corre 16 px por fila.
  Los parches se aplican con `bash device/lge/c660/patches/apply-patches.sh`
  desde la raíz, sobre árboles limpios. No correrlo ahora: ya están aplicados.
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
eventos reales de tecla (`getevent`) al deslizar el teclado. Se eliminó el
binario original (`kernel.bak-original`) del árbol; queda un solo kernel
compilado (`device/lge/c660/kernel`), recuperable del historial de git si
hiciera falta comparar.

Además se detectó y corrigió un bug real en `drivers/input/keyboard/kbd_pp2106.c`:
`pp2106_fetchkeys()` no validaba límites de fila/columna antes de indexar la
tabla de teclas. Cada `pp2106_hwreset()` (al iniciar el driver y en cada
resume de pantalla) dispara un falling-edge espurio de IRQ antes de que el
chip esté listo, y el bit-banging devuelve basura fuera de la grilla 7x7 real
— sin el chequeo, eso indexaba fuera de `pp2106_keycode[]` e inyectaba una
tecla fantasma en cada wake de pantalla (causaba que "se active el teclado
virtual solo"). Confirmado en `dmesg` real: ahora se descarta la lectura en
vez de inyectarla.

### Bug de parpadeo en `chargerlogo` (RESUELTO 2026-07-17)

Ver antes en este mismo documento: `chargerlogo` parpadeaba (imagen → negro →
imagen) en modo carga con el equipo apagado. Se descartó que fuera el binario
(confirmado byte a byte idéntico al de un nandroid stock real, igual que las
imágenes `.rle`) y se descartaron dos hipótesis de timing de vsync a nivel de
driver (no cambiaron nada en hardware real).

La causa real se encontró comparando el `.config` real de LG (extraído de
`/proc/config.gz` de un boot con el kernel stock genuino, compilado por
`lg-electronics@viewty2-desktop` en 2011) contra el nuestro. Prueba A/B en el
equipo real armando un boot.img híbrido (kernel stock + nuestro ramdisk/`
system`) confirmó que con el kernel stock **no** parpadea — o sea, la
diferencia estaba en el kernel, no en `chargerlogo` ni en el resto del ROM.

Dos diferencias de config resultaron ser la causa (ambas ya en
`cyanogenmod_muscat_defconfig`, y ya presentes sin usar en
`muscat-perf_defconfig`):

- `CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y` (en vez de `_INTERACTIVE`) — con
  el governor "interactive" el CPU arranca en su clock más bajo hasta detectar
  carga sostenida, justo cuando `chargerlogo` necesita decodificar RLE y
  componer el frame rápido en modo carga (equipo recién arrancando).
- `CONFIG_FRAMEBUFFER_CONSOLE=y` (+ `CONFIG_FONTS`/`CONFIG_FONT_6x11`) —
  registra una consola de framebuffer que engancha al driver de video más
  temprano en el boot.

Probado individualmente: el cambio de governor solo **no** alcanzó (seguía
parpadeando). Con los dos cambios juntos, confirmado sin parpadeo en el
equipo real. No apagar `CONFIG_FRAMEBUFFER_CONSOLE`: el governor solo no
basta, y chargerlogo lo necesita junto con `CONFIG_FONT_6x11`.

### Cursor `ANDROID_` (RESUELTO, kernel #10)

El bootlogo de oemsbl se queda en el panel y fbcon dibuja encima el cursor
subrayado (`CUR_UNDERLINE`). `CONFIG_LOGO` y `CONFIG_FB_MSM_LOGO` están
apagados. `msm_fb_open` volvía a activar la consola cuando `ref_cnt` pasaba
de 0, y eso redibujaba el cursor sobre la UI.

En `kernel-c660-src/drivers/video/msm/msm_fb.c`, `msm_fb_open` ya no llama
`msm_fb_set_console_inactive(0)`. La consola sigue registrada para
chargerlogo. El zImage anterior no se versiona (`kernel.bak-fbcon` queda
solo en local). El que corre es el #10 (`2.6.35.10-cyanogenmod`,
2026-10-05 01:09:55 UTC).
`dmesg` todavía dice una vez `Console: switching to colour frame buffer
device 40x29` al encender el panel. Confirmado en el equipo: `ANDROID_` no
vuelve. El `kernel` del device tree es este zImage; el zip de la SD es
anterior y no lo trae.

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

### Cámara, radio y canales SMD

- **Preview de cámara con Cb/Cr invertidos (RESUELTO 2026-10-04).** El
  JPEG ya salía bien. El preview que llega a `CameraService` sigue siendo
  YUV420SP (`w*h*3/2`), posteado como `HAL_PIXEL_FORMAT_YCrCb_420_SP`, con
  los pares de croma al revés: el azul se ve naranja. No hay una conversión
  YUV→RGB dentro de `libcamera.so`; `runPreviewThread` solo entrega
  `CAMERA_MSG_PREVIEW_FRAME`. El mismo `libcamera.so` (md5 idéntico al
  stock) se ve bien en la ROM de LG porque `com.lge.camera` y el framework
  LG le piden el buffer de otra forma. La app stock en CM7 hace
  `SIGSEGV`/`dlfree` (odex contra el framework LG) y se descartó
  des-odexearla.
  El arreglo es solo del C660: `BOARD_CAMERA_PREVIEW_SWAP_CHROMA` en
  `BoardConfig.mk`. `libcameraservice/Android.mk` pasa
  `-DCAMERA_PREVIEW_SWAP_CHROMA` y `Client::handlePreviewData` intercambia
  cada par de bytes del plano de croma (offset `w*h`, largo `w*h/2`) antes
  de `postBuffer`. El JPEG no se toca. El Y210 no define el flag.
  Confirmado en el equipo: el azul se ve azul, y un vídeo grabado (usa el
  mismo heap de preview) también. En el teléfono,
  `/system/lib/libcameraservice.so` es el binario nuevo (55092 bytes,
  2026-10-05). El zip `cm-7.2.0-c660.zip` de la SD es anterior y no lo trae.
  Caminos cerrados, no retomar:
  - **Confirmado también con el kernel stock genuino de LG** (mismo
    `/system`, boot.img híbrido del A/B de `chargerlogo` el 2026-07-17):
    el azul sigue naranja. No es `kernel-c660-src`.
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
    siendo válida. El swap de croma de Gingerbread no se porta solo: ICS
    ya no pasa el preview por ese `postBuffer`.
- **SIM / bloqueo de red (PH-NET), dejado para el final.** Probado con SIM
  Claro Perú (MCC 71610): UMTS limitado, voz denegada, operador vacío,
  `gsm.sim.state=UNKNOWN` (no es PIN ni PUK). El lock no es Claro; en un
  C660 de Perú lo probable es Movistar o Entel. OSIPTEL "limpio" solo dice
  que el IMEI no está reportado robado. IMEI `359543040892644`, SVN `00`.
  No adivinar el NCK. Un KDZ Telcel (México) no lo libera y no se usan sus
  blobs. Detalle en la nota del 2026-10-04. `rild` sí habla con el módem
  (RSSI, celdas WCDMA) por `/dev/smd0`. Llamadas, SMS, datos y NITZ siguen
  sin probarse con la SIM del operador del lock.
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

## Estado funcional (LG-C660h, 2026-10-04)

En marcha: `CyanogenMod-7.2.0-c660`, `ro.build.type=user`, kernel
`2.6.35.10-cyanogenmod #10 PREEMPT Mon Oct 5 01:09:55 UTC 2026`.

| Función | Estado | Nota |
| --- | --- | --- |
| Arranque / launcher | Funciona | Imagen ~23 s, launcher ~30 s, CPU en performance a 800 MHz. No es un cuelgue. No cambiar el governor. |
| Gráficos (SurfaceFlinger) | Funciona | Compositing real. El cursor `ANDROID_` ya no vuelve (kernel #10). |
| Encendido de pantalla | Dejado así | ~410 ms: cada wake hace reset GPIO + `do_ilitek_init` (Sleep Out 0x11 + 120 ms) porque `disp_off` corta reset y EBI2. No saltar el init: riesgo de panel en negro. |
| WiFi | Funciona | Asociación y DHCP confirmados (red DEPA2). |
| Bluetooth | Funciona | Scan ve equipos. El `StopDiscovery: Invalid discovery session` quedó resuelto; dos scans seguidos arrancan y terminan. |
| RIL / baseband | Parcial | El módem responde. La SIM Claro no registra: bloqueo PH-NET. Llamadas, SMS y datos pendientes de la SIM del lock. |
| Reloj | Pendiente con la SIM | El módem entrega 2026-04-15 por `GET_JULIAN`. Sin NITZ no hay otra hora. No es un bug de kernel. |
| Sensores | Funciona | Acelerómetro y magnetómetro con datos reales. |
| Cámara | Funciona | Preview con croma corregida. El azul se ve azul. |
| Video | Funciona | Grabación con color correcto, confirmada por el usuario. |
| FM Radio | Funciona | Audio confirmado. |
| Galería 3D | Funciona | Confirmado por el usuario. |
| Teclado físico QWERTY | Funciona | Kernel propio + descarte de tecla fantasma en `kbd_pp2106`. |
| Chargerlogo | Funciona | Sin parpadeo. Hacen falta el governor performance y `CONFIG_FRAMEBUFFER_CONSOLE`. |
| GPS | Sin confirmar | Una sesión de QApp: `loc_eng_data_conn_failed`, fix 0,0. Hace falta datos móviles para saber si es el chip. |
| Canales SMD extra | Ruido de módem | `DATA8/9/12/13/14_CNTL` abren `-19`. `DATA5/6/7` funcionan. No se arregla desde la ROM. |
| `install-recovery.sh` | No es un bug | El zip no lo trae y el `set_perm` del recovery falla. El arranque sigue. Solo reinstalaría CWM en cada boot. |

## Instalación

CWM 5.0.2.7 (`recovery-clockwork-5.0.2.7-c660.img`) flasheado vía `flash_image`
desde `adb shell` (root). No hay fastboot ni `adb sideload`.
`extendedcommand` exige firma de ROM Manager y falla con
`SD Card marker not found` si se escribe a mano.

`/cache/recovery/command` sí instala un zip, con una sola línea y sin
`boot-recovery` delante (`get_args` trata cada línea como un argumento):

```bash
adb shell 'echo --update_package=/sdcard/cm-7.2.0-c660.zip > /cache/recovery/command'
adb reboot recovery
```

La comprobación de firma sigue activa en esa vía. El menú físico
(`install zip from sdcard`) también funciona. Botones: recovery
**Vol− + Home + Power**; download **Vol+ + Atrás + Power**.

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

## Nota 2026-10-04 — SIM, reloj, ROM Telcel

El equipo estaba en CyanogenMod-7.2.0-c660. Se hizo factory-reset de `/data`
y se insertó una SIM Claro Perú.

Radio: servicio UMTS limitado, registro de voz denegado, operador vacío, sin
MCC 71610. `gsm.sim.state` se quedó en `UNKNOWN`. El log mostró la SIM GSM
trabada en personalización de red (PH-NET). No es PIN ni PUK de la SIM. El
teléfono está bloqueado a operador, y el lock no es Claro (una SIM Claro
habría registrado si lo fuera). En un C660 de 2011 en Perú, el lock que queda
como probable es Movistar o Entel. SIM, NITZ, llamadas, SMS y datos quedan
pendientes hasta tener una SIM del operador del lock. No intentar códigos de
liberación.

IMEI `359543040892644`. Revisado en OSIPTEL: limpio (no robado). El SVN se
muestra como `00` junto al IMEI; no forma parte del IMEI.

Reloj: no es un bug de kernel. `hctosys` copia el `GET_JULIAN` del módem. Este
baseband devuelve 2026-04-15. El Y210 usa el mismo camino y obtuvo un TOD
correcto. NITZ no llegó. Cambiar la zona horaria solo mueve lo que se muestra.
Queda pendiente junto con la SIM.

Después se flasheó un stock Telcel (México): no había KDZ de Perú. No es el
nandroid de julio ni el V10a de Perú del que salieron los blobs. Tras ese
flasheo, `*#06#` sigue mostrando el mismo IMEI más SVN `00`.

Los blobs de `vendor/lge/c660` ya se extrajeron de la unidad Perú V10a. No
re-extraer ni reemplazar esos blobs desde el ROM Telcel. No mezclar librerías
Telcel en este árbol. Reinstalar el zip CM7 que ya existe no necesita un pull
nuevo del system Telcel: `out/target/product/c660/cm-7.2.0-c660.zip` y los
blobs de Perú ya están en el árbol.

Leído por adb (solo lectura, sin reboot), sistema en marcha:

- `ro.product.model` = `LG-C660h`
- `ro.build.fingerprint` = `LGE/lge_muscat/muscat:2.3.4/GRJ22/V10a-Aug-23-2011.2ED2FC1835:user/release-keys`
- `ro.build.description` = `muscat-user 2.3.4 GRJ22 V10a-Aug-23-2011.2ED2FC1835 release-keys`
- `gsm.version.baseband` = `V07u-000-000-MAR-23-2009`
- `ro.product.device` = `muscat`

Esa lectura fue con el stock Telcel todavía arrancado. El fingerprint repite
el string del V10a Perú, pero `ro.product.locale.region` = `MX` y en
`/system/app` estaban `TelcelUrl.apk` y `TN55-Telcel-1002.apk`. Después el
usuario reinstaló CM7. CWM 5.0.2.7 sobrevivió: el zip se instaló y el equipo
volvió a `CyanogenMod-7.2.0-c660`.

## Qué hay en el equipo y qué no trae el zip

`/sdcard/cm-7.2.0-c660.zip` (85271855 bytes, 2026-10-04 00:53) es el paquete
7.2.0 de ese día: `ro.modversion=CyanogenMod-7.2.0-c660`, `ro.build.type=user`,
sin `checkjni`. Volver a flashearlo pisa tres arreglos que se empujaron
después y que el zip no contiene:

- `kernel` #10, sin el cursor `ANDROID_` (`device/lge/c660/kernel`; el
  anterior está en `kernel.bak-fbcon`).
- `/system/lib/libcameraservice.so` con el swap de croma del preview.
- `/system/framework/framework.jar` con el parche de Bluetooth
  (`patches/frameworks_base_bluetooth.patch`). En el equipo pesa 3115137
  bytes. No hay `framework.odex`; zygote lo tomó tras el reboot y el caché
  Dalvik se regeneró. Dos scans seguidos (00:45 y 00:47, reloj del módem)
  vieron equipos y terminaron sin `Invalid discovery session`.

Esos tres cambios sí están en el árbol de fuentes. Un `bacon` nuevo los
metería en el zip. Hasta entonces, no reinstalar el zip de la SD si se
quiere conservar preview, cursor y Bluetooth.

`install-recovery.sh` no está en `/system/bin`. El `set_perm` que falla en
el recovery no es un bug.

## Qué no se toca

- No acortar el wake del panel Ilitek saltándose `do_ilitek_init`.
- No apagar `CONFIG_FRAMEBUFFER_CONSOLE` ni cambiar el governor performance.
- No escribir la hora con `SET_JULIAN` hasta que se pida. Un binario
  `setrtc` llegó a `/data/local/tmp`, salió por falta de argumentos y no
  llamó al módem. El factory reset lo borró.
- No mezclar blobs Telcel en `vendor/lge/c660`.
- No adivinar el NCK del bloqueo de red.
- El arreglo de Bluetooth vive en `frameworks/base` (compartido con el
  Y210) y la copia para reaplicar está en
  `device/lge/c660/patches/`. No correr `apply-patches.sh` sobre el árbol
  actual: el parche ya está aplicado.
