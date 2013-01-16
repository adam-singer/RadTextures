import 'dart:html';
import 'package:rad_textures/rad_textures_lib.dart';

void main() {
  window.on.load.add((e) => _create());
}

void _create() {
  CanvasElement canvas = query("#canvas");
  CanvasRenderingContext2D ctx = canvas.context2d;
  ctx.fillStyle = 'black';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ImageData imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  num scale = 0.013;
  SimplexNoise simplexNoise = new SimplexNoise();
  for(int x = 0; x < canvas.width; x++) {
    for(int y = 0; y < canvas.height; y++) {
      num sample = simplexNoise.noise2(x * scale, y * scale);
      imageData.data[(y * canvas.width + x) * 4 + 0] = 0;
      imageData.data[(y * canvas.width + x) * 4 + 1] = 
          ((sample * 0.5 + 0.5) * 255).toInt();
      imageData.data[(y * canvas.width + x) * 4 + 2] = 0;
      imageData.data[(y * canvas.width + x) * 4 + 3] = 255;
    }
  }
  ctx.putImageData(imageData, 0, 0, 0, 0, canvas.width, canvas.height);
}
