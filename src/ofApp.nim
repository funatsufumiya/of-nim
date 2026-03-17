# Nim-friendly wrapper for the C++ ofn_* callbacks

type
  UpdateFn* = proc(user: pointer){.cdecl.}
  DrawFn*   = proc(user: pointer){.cdecl.}
  KeyPressedFn*    = proc(user: pointer, key: cint){.cdecl.}
  KeyReleaseFn* = proc(user: pointer, key: cint){.cdecl.}
  MouseMoveFn* = proc(user: pointer, x: cint, y: cint){.cdecl.}
  MouseButtonFn* = proc(user: pointer, x: cint, y: cint, button: cint){.cdecl.}
  EnterExitFn* = proc(user: pointer, x: cint, y: cint){.cdecl.}
  ResizeFn* = proc(user: pointer, w: cint, h: cint){.cdecl.}
  DragFn* = proc(user: pointer, info: pointer){.cdecl.}
  MessageFn* = proc(user: pointer, msg: pointer){.cdecl.}
  ExitFn* = proc(user: pointer){.cdecl.}

{.emit: """
#include <memory>
#include "ofMain.h"

using UpdateFn = void(*)(void*);
using DrawFn   = void(*)(void*);
using KeyPressedFn    = void(*)(void*, int);
using KeyReleaseFn = void(*)(void*, int);
using MouseMoveFn = void(*)(void*, int, int);
using MouseButtonFn = void(*)(void*, int, int, int);
using EnterExitFn = void(*)(void*, int, int);
using ResizeFn = void(*)(void*, int, int);
using DragFn = void(*)(void*, void*);
using MessageFn = void(*)(void*, void*);
using ExitFn = void(*)(void*);

struct NimCallbacks {
  UpdateFn update;
  DrawFn draw;
  KeyPressedFn keyPressed;
  KeyReleaseFn keyReleased;
  MouseMoveFn mouseMoved;
  MouseButtonFn mouseDragged;
  MouseButtonFn mousePressed;
  MouseButtonFn mouseReleased;
  EnterExitFn mouseEntered;
  EnterExitFn mouseExited;
  ResizeFn windowResized;
  DragFn dragEvent;
  MessageFn gotMessage;
  ExitFn exit;
  void* user;
};

inline NimCallbacks* ofn_makeCallbacks() {
  NimCallbacks* p = new NimCallbacks();
  p->update = nullptr;
  p->draw = nullptr;
  p->user = nullptr;
  p->keyPressed = nullptr;
  p->keyReleased = nullptr;
  p->mouseMoved = nullptr;
  p->mouseDragged = nullptr;
  p->mousePressed = nullptr;
  p->mouseReleased = nullptr;
  p->mouseEntered = nullptr;
  p->mouseExited = nullptr;
  p->windowResized = nullptr;
  p->dragEvent = nullptr;
  p->gotMessage = nullptr;
  p->exit = nullptr;
  return p;
}

class NimApp : public ofBaseApp {
  NimCallbacks* cb;
public:
  NimApp(NimCallbacks* c): cb(c) {}
  void setup() override { if(cb && cb->update) cb->update(cb->user); }
  void update() override { if(cb && cb->update) cb->update(cb->user); }
  void draw() override   { if(cb && cb->draw)   cb->draw(cb->user);  }
  void keyPressed(int k) override { if(cb && cb->keyPressed) cb->keyPressed(cb->user, k); }
  void keyReleased(int k) override { if(cb && cb->keyReleased) cb->keyReleased(cb->user, k); }
  void mouseMoved(int x, int y) override { if(cb && cb->mouseMoved) cb->mouseMoved(cb->user, x, y); }
  void mouseDragged(int x, int y, int button) override { if(cb && cb->mouseDragged) cb->mouseDragged(cb->user, x, y, button); }
  void mousePressed(int x, int y, int button) override { if(cb && cb->mousePressed) cb->mousePressed(cb->user, x, y, button); }
  void mouseReleased(int x, int y, int button) override { if(cb && cb->mouseReleased) cb->mouseReleased(cb->user, x, y, button); }
  void mouseEntered(int x, int y) override { if(cb && cb->mouseEntered) cb->mouseEntered(cb->user, x, y); }
  void mouseExited(int x, int y) override { if(cb && cb->mouseExited) cb->mouseExited(cb->user, x, y); }
  void windowResized(int w, int h) override { if(cb && cb->windowResized) cb->windowResized(cb->user, w, h); }
  void dragEvent(ofDragInfo dragInfo) override { if(cb && cb->dragEvent) cb->dragEvent(cb->user, (void*)&dragInfo); }
  void gotMessage(ofMessage msg) override { if(cb && cb->gotMessage) cb->gotMessage(cb->user, (void*)&msg); }
  void exit() override { if(cb && cb->exit) cb->exit(cb->user); }
};

inline void ofn_runWithCallbacks(int w, int h, NimCallbacks* cb) {
  // default to windowed
  ofGLFWWindowSettings s;
  s.setSize(w,h);
  s.windowMode = OF_WINDOW;
  auto win = ofCreateWindow(s);
  std::shared_ptr<NimApp> app = std::make_shared<NimApp>(cb);
  ofRunApp(win, app);
  ofRunMainLoop();
}

inline void ofn_runWithCallbacks_withFlag(int w, int h, NimCallbacks* cb, bool fullscreen) {
  ofGLFWWindowSettings s;
  s.setSize(w,h);
  s.windowMode = fullscreen ? OF_FULLSCREEN : OF_WINDOW;
  auto win = ofCreateWindow(s);
  std::shared_ptr<NimApp> app = std::make_shared<NimApp>(cb);
  ofRunApp(win, app);
  ofRunMainLoop();
}

inline void ofn_runWithCallbacks_withSettings(const ofGLWindowSettings& s_in, NimCallbacks* cb) {
  ofGLWindowSettings s = s_in;
  auto win = ofCreateWindow(s);
  std::shared_ptr<NimApp> app = std::make_shared<NimApp>(cb);
  ofRunApp(win, app);
  ofRunMainLoop();
}

extern "C" {
  inline void* ofn_makeCallbacks_c() {
    return (void*)ofn_makeCallbacks();
  }
  inline void ofn_runWithCallbacks_c(int w, int h, void* cb) {
    ofn_runWithCallbacks(w,h, (NimCallbacks*)cb);
  }
  inline void ofn_runWithCallbacks_fullscreen_c(int w, int h, void* cb, bool fullscreen) {
    ofn_runWithCallbacks_withFlag(w,h, (NimCallbacks*)cb, fullscreen);
  }
  inline void ofn_runWithCallbacks_settings_c(void* settingsPtr, void* cb) {
    ofn_runWithCallbacks_withSettings(*(ofGLWindowSettings*)settingsPtr, (NimCallbacks*)cb);
  }

  inline void ofn_setUpdate_c(void* cb, UpdateFn f) { ((NimCallbacks*)cb)->update = f; }
  inline void ofn_setDraw_c(void* cb, DrawFn f) { ((NimCallbacks*)cb)->draw = f; }
  inline void ofn_setKeyPressed_c(void* cb, KeyPressedFn f) { ((NimCallbacks*)cb)->keyPressed = f; }
  inline void ofn_setUser_c(void* cb, void* user) { ((NimCallbacks*)cb)->user = user; }
  inline void ofn_setKeyReleased_c(void* cb, KeyReleaseFn f) { ((NimCallbacks*)cb)->keyReleased = f; }
  inline void ofn_setMouseMoved_c(void* cb, MouseMoveFn f) { ((NimCallbacks*)cb)->mouseMoved = f; }
  inline void ofn_setMouseDragged_c(void* cb, MouseButtonFn f) { ((NimCallbacks*)cb)->mouseDragged = f; }
  inline void ofn_setMousePressed_c(void* cb, MouseButtonFn f) { ((NimCallbacks*)cb)->mousePressed = f; }
  inline void ofn_setMouseReleased_c(void* cb, MouseButtonFn f) { ((NimCallbacks*)cb)->mouseReleased = f; }
  inline void ofn_setMouseEntered_c(void* cb, EnterExitFn f) { ((NimCallbacks*)cb)->mouseEntered = f; }
  inline void ofn_setMouseExited_c(void* cb, EnterExitFn f) { ((NimCallbacks*)cb)->mouseExited = f; }
  inline void ofn_setWindowResized_c(void* cb, ResizeFn f) { ((NimCallbacks*)cb)->windowResized = f; }
  inline void ofn_setDragEvent_c(void* cb, DragFn f) { ((NimCallbacks*)cb)->dragEvent = f; }
  inline void ofn_setGotMessage_c(void* cb, MessageFn f) { ((NimCallbacks*)cb)->gotMessage = f; }
  inline void ofn_setExit_c(void* cb, ExitFn f) { ((NimCallbacks*)cb)->exit = f; }
}
""".}

proc ofn_makeCallbacks_c(): pointer {.importc: "ofn_makeCallbacks_c", cdecl.}
proc ofn_runWithCallbacks_c(w: cint, h: cint, cb: pointer) {.importc: "ofn_runWithCallbacks_c", cdecl.}
proc ofn_runWithCallbacks_fullscreen_c(w: cint, h: cint, cb: pointer, fullscreen: bool) {.importc: "ofn_runWithCallbacks_fullscreen_c", cdecl.}
proc ofn_runWithCallbacks_settings_c(settings: pointer, cb: pointer) {.importc: "ofn_runWithCallbacks_settings_c", cdecl.}

proc ofn_setUpdate_c(cb: pointer, f: UpdateFn) {.importc: "ofn_setUpdate_c", cdecl.}
proc ofn_setDraw_c(cb: pointer, f: DrawFn) {.importc: "ofn_setDraw_c", cdecl.}
proc ofn_setUser_c(cb: pointer, user: pointer) {.importc: "ofn_setUser_c", cdecl.}
proc ofn_setKeyPressed_c(cb: pointer, f: KeyPressedFn) {.importc: "ofn_setKeyPressed_c", cdecl.}
proc ofn_setKeyReleased_c(cb: pointer, f: KeyReleaseFn) {.importc: "ofn_setKeyReleased_c", cdecl.}
proc ofn_setMouseMoved_c(cb: pointer, f: MouseMoveFn) {.importc: "ofn_setMouseMoved_c", cdecl.}
proc ofn_setMouseDragged_c(cb: pointer, f: MouseButtonFn) {.importc: "ofn_setMouseDragged_c", cdecl.}
proc ofn_setMousePressed_c(cb: pointer, f: MouseButtonFn) {.importc: "ofn_setMousePressed_c", cdecl.}
proc ofn_setMouseReleased_c(cb: pointer, f: MouseButtonFn) {.importc: "ofn_setMouseReleased_c", cdecl.}
proc ofn_setMouseEntered_c(cb: pointer, f: EnterExitFn) {.importc: "ofn_setMouseEntered_c", cdecl.}
proc ofn_setMouseExited_c(cb: pointer, f: EnterExitFn) {.importc: "ofn_setMouseExited_c", cdecl.}
proc ofn_setWindowResized_c(cb: pointer, f: ResizeFn) {.importc: "ofn_setWindowResized_c", cdecl.}
proc ofn_setDragEvent_c(cb: pointer, f: DragFn) {.importc: "ofn_setDragEvent_c", cdecl.}
proc ofn_setGotMessage_c(cb: pointer, f: MessageFn) {.importc: "ofn_setGotMessage_c", cdecl.}
proc ofn_setExit_c(cb: pointer, f: ExitFn) {.importc: "ofn_setExit_c", cdecl.}

type OfApp* = object
  cb*: pointer
  user*: pointer

type OfAppConfig* = object
  update*: UpdateFn
  draw*: DrawFn
  keyPressed*: KeyPressedFn
  keyReleased*: KeyReleaseFn
  mouseMoved*: MouseMoveFn
  mouseDragged*: MouseButtonFn
  mousePressed*: MouseButtonFn
  mouseReleased*: MouseButtonFn
  mouseEntered*: EnterExitFn
  mouseExited*: EnterExitFn
  windowResized*: ResizeFn
  dragEvent*: DragFn
  gotMessage*: MessageFn
  exit*: ExitFn
  user*: pointer

proc makeOfApp*(
  update: UpdateFn = nil;
  draw: DrawFn = nil;
  keyPressed: KeyPressedFn = nil;
  keyReleased: KeyReleaseFn = nil;
  mouseMoved: MouseMoveFn = nil;
  mouseDragged: MouseButtonFn = nil;
  mousePressed: MouseButtonFn = nil;
  mouseReleased: MouseButtonFn = nil;
  mouseEntered: EnterExitFn = nil;
  mouseExited: EnterExitFn = nil;
  windowResized: ResizeFn = nil;
  dragEvent: DragFn = nil;
  gotMessage: MessageFn = nil;
  exit: ExitFn = nil;
  user: pointer = nil): OfApp =
  
  var a: OfApp
  a.cb = ofn_makeCallbacks_c()
  a.user = user
  if update != nil: ofn_setUpdate_c(a.cb, update)
  if draw != nil: ofn_setDraw_c(a.cb, draw)
  if keyPressed != nil: ofn_setKeyPressed_c(a.cb, keyPressed)
  if keyReleased != nil: ofn_setKeyReleased_c(a.cb, keyReleased)
  if mouseMoved != nil: ofn_setMouseMoved_c(a.cb, mouseMoved)
  if mouseDragged != nil: ofn_setMouseDragged_c(a.cb, mouseDragged)
  if mousePressed != nil: ofn_setMousePressed_c(a.cb, mousePressed)
  if mouseReleased != nil: ofn_setMouseReleased_c(a.cb, mouseReleased)
  if mouseEntered != nil: ofn_setMouseEntered_c(a.cb, mouseEntered)
  if mouseExited != nil: ofn_setMouseExited_c(a.cb, mouseExited)
  if windowResized != nil: ofn_setWindowResized_c(a.cb, windowResized)
  if dragEvent != nil: ofn_setDragEvent_c(a.cb, dragEvent)
  if gotMessage != nil: ofn_setGotMessage_c(a.cb, gotMessage)
  if exit != nil: ofn_setExit_c(a.cb, exit)
  if user != nil: ofn_setUser_c(a.cb, user)
  return a

proc makeOfApp*(cfg: OfAppConfig): OfApp =
  return makeOfApp(
    update = cfg.update,
    draw = cfg.draw,
    keyPressed = cfg.keyPressed,
    keyReleased = cfg.keyReleased,
    mouseMoved = cfg.mouseMoved,
    mouseDragged = cfg.mouseDragged,
    mousePressed = cfg.mousePressed,
    mouseReleased = cfg.mouseReleased,
    mouseEntered = cfg.mouseEntered,
    mouseExited = cfg.mouseExited,
    windowResized = cfg.windowResized,
    dragEvent = cfg.dragEvent,
    gotMessage = cfg.gotMessage,
    exit = cfg.exit,
    user = cfg.user)

proc run*(a: var OfApp; w: int = 800; h: int = 600; fullscreen: bool = false) =
  ofn_runWithCallbacks_fullscreen_c(cast[cint](w), cast[cint](h), a.cb, fullscreen)

proc runWithSettings*(a: var OfApp; settings: pointer) =
  ofn_runWithCallbacks_settings_c(settings, a.cb)
