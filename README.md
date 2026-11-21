# Panther FF Skin Viewer

Visor para iPhone y iPad con iOS 15 o posterior. La app guarda una copia local de lo que importas desde Archivos.

## Visor y vestidor

- **UnityFS** abre paquetes por su firma, incluso con extensiones desconocidas como `~3D` o `.3105`. Lee paquetes con bloques sin comprimir, LZMA, LZ4 o LZ4HC. En los paquetes con rutas de vestidor reconocibles, muestra los nombres internos por categoría. El paquete de ejemplo incluye recursos `DJmale Awakening` de cabello, rostro, torso, pantalón y zapatos. Estas referencias describen recursos presentes en el paquete y no indican cuáles están equipados.
- **Modelos 3D** admite escenas SCN, DAE, OBJ y USDZ compatibles con SceneKit. Para conservar texturas, usa un USDZ autocontenido.
- **Prendas** abre el personaje base en Visor, entra en Vestidor, selecciona la categoría y usa **Importar prenda**. Toca la prenda para añadirla o quitarla. Los modelos deben compartir origen, escala y pose. Las prendas con su propio esqueleto conservan su pose exportada.
- **Conjuntos** guarda el modelo base y las prendas elegidas. Para cambiar ropa, importa un modelo base al que se le puedan añadir las prendas sin superponer geometría.

La app todavía requiere exportar un personaje Unity a un formato de SceneKit para verlo en 3D. Los paquetes de Free Fire pueden guardar piezas por separado y combinarse con recursos externos del juego. El catálogo se llena con los modelos importados.

## Compilación

En GitHub, abre **Actions → Build unsigned IPA**. El flujo se ejecuta con cambios en `main` o mediante **Run workflow**. Al terminar, descarga el artefacto y firma la IPA para instalarla.

En macOS, instala XcodeGen y ejecuta `xcodegen generate` para abrir el proyecto con Xcode.

El decodificador LZMA de Igor Pavlov proviene del SDK de 7-Zip, commit `d3296e39e1f1f92c7b41c0c3848e65640428d42d`. Sus archivos conservan las declaraciones de dominio público.
