/**
 * Aclara el dibujo impreso, sin taparlo.
 *
 * ## Qué hace
 *
 * Un velo del color del papel, semitransparente, sobre la silueta del dibujo. El dibujo impreso
 * **sigue viéndose, pero apagado**, y el animado va nítido encima. Lo de atrás no es una figura
 * ajena: es el dibujo del niño, con los colores que él pintó, un poco más claro.
 *
 * ## Por qué no taparlo
 *
 * Se probaron siete formas de taparlo y todas fallaron:
 *
 * 1. **Papel camuflado con grano** sobre la silueta. Muestreaba el color **fuera** del marco y
 *    con la hoja inclinada esa muestra caía en la mesa: en terreno salió 25 tonos más oscuro,
 *    con desviación 29 donde el papel tenía 7,6.
 * 2. **Sombra translúcida** al 22%: una sombra oscurece, no tapa. Dejaba el trazo negro visible
 *    y encima oscurecía el resto — **284%** de píxeles oscuros contra el dibujo sin tapar.
 * 3. **Gris opaco** sobre la silueta. Tapaba, pero **tenía forma de bicho** y se leía como un
 *    segundo dinosaurio quieto mientras el de verdad paseaba.
 * 4. **Silueta agrandada**: no arregla la forma. Dilatando ±55 px el parecido sigue en IoU 0,54:
 *    es un dinosaurio gordo, no otra cosa.
 * 5. **Agujero rasgado**: resolvía la forma, pero era un boquete que llamaba más la atención que
 *    el dibujo que venía a tapar.
 * 6. **Papel roto con solapas**: bonito de explicar, feo en pantalla.
 * 7. **Relleno entre las cuatro marcas**: medía perfecto —salto 0 en cuatro luces— pero tapa
 *    media hoja.
 *
 * El problema de fondo es que **taparlo bien exige acertarle al papel**, y el papel cambia con
 * la luz, el ángulo y la cámara. Un velo no tiene que acertarle a nada: **multiplica** lo que
 * haya debajo, así que aclara igual sea cual sea el papel.
 */

/**
 * Cuánto se aclara el dibujo impreso, de 0 (nada) a 1 (desaparece).
 *
 * 0,55 lo deja claramente detrás sin borrarlo: sigue leyéndose como el dibujo del niño.
 */
const VELO = 0.55;

/**
 * Cuánto se agranda la silueta del velo, en px de textura.
 *
 * No es cosmético: **el personaje crece hasta un 124% mientras se anima** —las patas al
 * balancearse, el rebote— y llega a medir el 195% de su dibujo impreso. Si el velo fuera del
 * tamaño exacto de la silueta, cada movimiento dejaría asomar el trazo impreso sin aclarar.
 */
const CRECE = 6;

/**
 * Dibuja el velo en coordenadas de textura. Quien llama ya puso la transformación de la hoja.
 *
 * @param paper  [r, g, b] del papel, medido por el TextureSampler
 */
export function drawPaperPatch(context, character, paper) {
  if (!character) return;
  const [tw, th] = character.frame.texture;
  const [r, g, b] = (paper ?? [255, 255, 255]).map((v) => Math.round(v));

  // La silueta engordada, en un lienzo aparte. La dilatación se hace uniendo copias desplazadas
  // con `source-over`: hacerlo con `destination-in` sobre el propio velo NO engorda, hace la
  // INTERSECCIÓN, o sea erosiona. Ese error dejaba el trazo impreso asomando por fuera.
  const velo = document.createElement("canvas");
  velo.width = tw;
  velo.height = th;
  const v = velo.getContext("2d");
  const sil = character.silhouette;
  for (let dx = -CRECE; dx <= CRECE; dx += 1) {
    for (let dy = -CRECE; dy <= CRECE; dy += 1) {
      if (dx * dx + dy * dy > CRECE * CRECE) continue;
      v.drawImage(sil, dx, dy, tw, th);
    }
  }
  v.globalCompositeOperation = "source-in";
  v.fillStyle = `rgba(${r}, ${g}, ${b}, ${VELO})`;
  v.fillRect(0, 0, tw, th);

  context.drawImage(velo, 0, 0);
}
