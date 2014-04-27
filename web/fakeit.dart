import 'dart:html';
import 'dart:math' as Math;
import 'dart:web_gl' as webgl;
import 'package:vector_math/vector_math.dart';
import 'shader.dart';
import 'texture.dart';
import 'model.dart';

var scene;
void main() {
  var canvas = document.querySelector("#glCanvas");
  scene = new FakeItScene(canvas);
  window.onResize.listen((_) => scene.resize());
  
  animate(0.0);
}

void animate(double time) {  
  scene.animate(time);
  scene.render();
  
  window.animationFrame
    ..then((time) => animate(time));
}


class FakeItScene {
  CanvasElement _canvas;
  int _width, _height;
  webgl.RenderingContext _gl;
  Shader _objShader, _planeShader;
  Model _cube, _plane;
  Matrix4 mProjection, mModelView;
  Texture _planeTex;

  FakeItScene(this._canvas) {
    _width  = _canvas.width;
    _height = _canvas.height;
    _gl     = _canvas.getContext("webgl");
    
    var ext = _gl.getExtension("OES_standard_derivatives");

    mProjection = makePerspectiveMatrix(1.0, 1.0, 0.01, 100.0);
    mModelView  = new Matrix4.identity();

    _initShaders();
    _gl.enable(webgl.DEPTH_TEST);
    _gl.clearColor(0.764, 0.831, 0.878, 1);
    resize();
    
    _cube = new Model(_gl)
      ..generateCube(1.0);
    _plane = new Model(_gl)
      ..generatePlane(1000.0, -0.5);
    
    _planeTex = new Texture(_gl)
      ..loadImageUrl("grid3.png");
  }
  
  void resize() {
    _width = window.innerWidth;
    _height = window.innerHeight;
    _canvas.width = _width;
    _canvas.height = _height;
    
    var ar = _width / _height;

    _gl.viewport(0, 0, _width, _height);
    mProjection = makePerspectiveMatrix(1.0 / Math.min(ar, 1.0), ar, 0.01, 100.0);
  }
  
  void animate(double time) {
    mModelView  = new Matrix4.identity().translate(0.0, 0.0, -2.0);
    mModelView.rotateX((Math.sin(time*0.00025) + 1.2) * 0.5);
    mModelView.rotateY(time * 0.0005);
  }
  
  void render() {
    _gl.clear(webgl.COLOR_BUFFER_BIT);
    
    _objShader.use();
    _gl.uniformMatrix4fv(_objShader.uniforms['uProjection'], false, mProjection.storage);
    _gl.uniformMatrix4fv(_objShader.uniforms['uModelView'],  false, mModelView.storage);
    _cube.bind();
    _cube.draw();
    
    _planeShader.use();
    _gl.uniformMatrix4fv(_planeShader.uniforms['uProjection'], false, mProjection.storage);
    _gl.uniformMatrix4fv(_planeShader.uniforms['uModelView'],  false, mModelView.storage);
    _gl.uniform1i(_planeShader.uniforms['uTexture'], 0);
    _gl.uniform1f(_planeShader.uniforms['uTexScale'], 8000.0);
    _gl.activeTexture(webgl.TEXTURE0);
    _planeTex.bind();
    _plane.bind();
    _plane.draw();
  }
  
  void _initShaders() {
    String vsObject = """
precision mediump int;
precision mediump float;

attribute vec3  aPosition;
attribute vec3  aNormal;
attribute vec2  aTexture;
attribute vec3  aEdge;

uniform mat4 uProjection;
uniform mat4 uModelView;

varying vec3 vNormal;
varying vec3 vEdge;

void main() {
  gl_Position = uProjection * uModelView * vec4(aPosition, 1.0);
  
  vNormal = aNormal;
  vEdge = aEdge;
}
    """;
    
    String fsObject = """
#extension GL_OES_standard_derivatives : enable

precision mediump int;
precision mediump float;

varying vec3 vNormal;
varying vec3 vEdge;

void main() {
  const float edgeWidth   = 1.0;
  const float smoothWidth = 1.5;
  const vec3  lightDir    = vec3(0.4, 0.824, 0.4);

  vec3 deriv     = fwidth(vEdge);
  vec3 edges     = smoothstep(vec3(1.0)-(deriv*smoothWidth), 
                              vec3(1.0)-(deriv*edgeWidth), vEdge); 
  float edge     = max(edges.x, edges.y);
  float diffuse  = dot(vNormal, lightDir);
  vec3 ambColor  = vec3(0.5);
  vec3 fillColor = vec3(1.0) * diffuse + ambColor * (1.0-diffuse);
  vec3 edgeColor = vec3(0.0, 0.0, 0.0);
  gl_FragColor   = vec4(mix(fillColor, edgeColor, edge), 1.0);
}
    """;
    
    _objShader = new Shader(_gl, vsObject, fsObject, 
        {'aPosition': 0, 'aNormal': 1, 'aTexture': 2, 'aEdge': 3});
    
    
    String vsPlane = """
precision mediump int;
precision mediump float;

attribute vec3  aPosition;
attribute vec3  aNormal;
attribute vec2  aTexture;

uniform mat4  uProjection;
uniform mat4  uModelView;
uniform float uTexScale;

varying vec3 vNormal;
varying vec2 vTexture;

void main() {
  gl_Position = uProjection * uModelView * vec4(aPosition, 1.0);
  
  vNormal = aNormal;
  vTexture = aTexture * uTexScale;
}
    """;
    
    String fsPlane = """
precision mediump int;
precision mediump float;

varying vec3 vNormal;
varying vec2 vTexture;

uniform sampler2D uTexture;

void main() {
  gl_FragColor = vec4(texture2D(uTexture, vTexture).rgb, 1.0);
}
    """;

    _planeShader = new Shader(_gl, vsPlane, fsPlane, 
        {'aPosition': 0, 'aNormal': 1, 'aTexture': 2});

  }
}