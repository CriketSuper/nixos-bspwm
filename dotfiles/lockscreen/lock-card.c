/* Presentation only: the upstream prompt, protocol and PAM checks stay intact. */
#include <X11/extensions/shape.h>
static int criket_input_prompt;
static int criket_input_secret;
static int criket_password_error;
static unsigned long criket_border, criket_field, criket_accent;
static Drawable criket_draw_targets[MAX_WINDOWS];
static Window criket_shaped_windows[MAX_WINDOWS];
#ifdef HAVE_XFT_EXT
static XftFont *criket_clock_font, *criket_small_font;
static XftColor criket_muted_color;
#endif

static void CriketRoundRect(Drawable d, GC gc, int x, int y,
                            int w, int h, int r) {
  XFillRectangle(display, d, gc, x+r, y, w-2*r, h);
  XFillRectangle(display, d, gc, x, y+r, w, h-2*r);
  XFillArc(display,d,gc,x,y,2*r,2*r,0,360*64);
  XFillArc(display,d,gc,x+w-2*r,y,2*r,2*r,0,360*64);
  XFillArc(display,d,gc,x,y+h-2*r,2*r,2*r,0,360*64);
  XFillArc(display,d,gc,x+w-2*r,y+h-2*r,2*r,2*r,0,360*64);
}

static unsigned long CriketPixel(const char *name) {
  XColor c, exact;
  if (XAllocNamedColor(display, DefaultColormap(display,DefaultScreen(display)),name,&c,&exact))
    return c.pixel;
  return xcolor_foreground.pixel;
}

/* font_kind: 0 normal, 1 clock, 2 caption. */
static void CriketText(int i, int cx, int y, const char *text,
                       int font_kind, int warning) {
#ifdef HAVE_XFT_EXT
  XftFont *font = font_kind == 1 ? criket_clock_font :
                   font_kind == 2 ? criket_small_font : xft_font;
  if (font != NULL) {
    XGlyphInfo extents;
    int len = strlen(text);
    XftTextExtentsUtf8(display,font,(const FcChar8 *)text,len,&extents);
    XftDrawStringUtf8(xft_draws[i], warning ? &xft_color_warning :
                       font_kind == 2 ? &criket_muted_color : &xft_color_foreground,
                       font,cx-(int)extents.xOff/2,y,(const FcChar8 *)text,len);
    return;
  }
#endif
XDrawString(display,criket_draw_targets[i],warning ? gcs_warning[i] : gcs[i],
              cx-TextWidth(text,strlen(text))/2,y,text,strlen(text));
}

static void CriketDisplayMessage(const char *title, const char *str,
                                  int warning) {
  /* Keep the last input frame while PAM verifies; avoid a one-frame status flash. */
  if (!warning && !strcmp(title,"Processing...")) return;
if (warning && !strcmp(str,"Пароль не принят")) criket_password_error=1;
  if (criket_input_secret && strspn(str,"*") > 0) criket_password_error=0;
  if (criket_input_secret && criket_password_error) {
    title="Пароль не принят";
    warning=1;
  }
  static int initialized;
  if (!initialized) {
    criket_border=CriketPixel("#353b50");
    criket_field=CriketPixel("#222738");
    criket_accent=CriketPixel("#89b4fa");
#ifdef HAVE_XFT_EXT
    criket_clock_font=XftFontOpenName(display,DefaultScreen(display),"Noto Sans:style=Light:size=38");
    criket_small_font=XftFontOpenName(display,DefaultScreen(display),"Noto Sans:size=11");
    XftColorAllocName(display,DefaultVisual(display,DefaultScreen(display)),
                     DefaultColormap(display,DefaultScreen(display)),"#a6adc8",&criket_muted_color);
#endif
    initialized=1;
  }
  int caps=0, multiple=0;
  const char *indicators=GetIndicators(&caps,&multiple);
  char layout[96];
  const char *short_layout=indicators;
#ifdef HAVE_XKB_EXT
  XkbStateRec state;
  if (have_xkb_ext && XkbGetState(display,XkbUseCoreKbd,&state)==Success)
    short_layout=state.group == 0 ? "EN" : state.group == 1 ? "RU" : indicators;
#endif
  snprintf(layout,sizeof(layout),"%s%s%s",short_layout,
           multiple ? "   ·   Alt+Shift" : "",caps ? "   ·   Caps Lock" : "");
  char clock[32]="", date[96]="";
  time_t now=time(NULL);
  struct tm local;
  if (localtime_r(&now,&local)) {
    strftime(clock,sizeof(clock),"%H:%M",&local);
    strftime(date,sizeof(date),"%d.%m.%Y",&local);
  }
if (!strcmp(title,"Processing...")) title="Проверка пароля…";
  else if (!strcmp(title,"Error")) title="Не удалось разблокировать";
  const int width=460, height=310;
  UpdatePerMonitorWindows(per_monitor_windows_dirty,width,height,x_offset,y_offset);
  per_monitor_windows_dirty=0;
  for (size_t i=0;i<num_windows;++i) {
    /* Shape only the auth card. The full-screen protection remains rectangular. */
    int event_base,error_base;
    if (criket_shaped_windows[i]!=windows[i] && XShapeQueryExtension(display,&event_base,&error_base)) {
      Pixmap mask=XCreatePixmap(display,windows[i],width,height,1);
      GC mgc=XCreateGC(display,mask,0,NULL);
      XSetForeground(display,mgc,0);
      XFillRectangle(display,mask,mgc,0,0,width,height);
      XSetForeground(display,mgc,1);
      CriketRoundRect(mask,mgc,0,0,width,height,24);
      XShapeCombineMask(display,windows[i],ShapeBounding,0,0,mask,ShapeSet);
      XFreeGC(display,mgc);
      XFreePixmap(display,mask);
      criket_shaped_windows[i]=windows[i];
    }
Pixmap frame=XCreatePixmap(display,windows[i],width,height,
                               DefaultDepth(display,DefaultScreen(display)));
    criket_draw_targets[i]=frame;
#ifdef HAVE_XFT_EXT
    XftDraw *window_draw=xft_draws[i];
    xft_draws[i]=XftDrawCreate(display,frame,DefaultVisual(display,DefaultScreen(display)),
                              DefaultColormap(display,DefaultScreen(display)));
#endif
    XSetForeground(display,gcs[i],xcolor_background.pixel);
    XFillRectangle(display,frame,gcs[i],0,0,width,height);
    XSetForeground(display,gcs[i],criket_border);
    CriketRoundRect(frame,gcs[i],0,0,width,height,24);
    XSetForeground(display,gcs[i],xcolor_background.pixel);
    CriketRoundRect(frame,gcs[i],1,1,width-2,height-2,23);
    CriketText(i,width/2,78,clock,1,0);
    CriketText(i,width/2,103,date,2,0);
    CriketText(i,width/2,143,criket_input_secret && !criket_password_error ? "Экран заблокирован" : title,0,warning);
    XSetForeground(display,gcs[i],warning ? xcolor_warning.pixel : criket_accent);
    CriketRoundRect(frame,gcs[i],40,166,width-80,60,15);
    XSetForeground(display,gcs[i],criket_field);
    CriketRoundRect(frame,gcs[i],41,167,width-82,58,14);
    if (criket_input_secret && password_prompt == PASSWORD_PROMPT_ASTERISKS) {
      /* Only consume the already masked display string, never password bytes. */
      size_t count=strspn(str,"*");
      size_t visible=count > 24 ? 24 : count;
      char dots[24*3+1];
      for (size_t dot=0;dot<visible;++dot)
        memcpy(dots+dot*3,"\xe2\x80\xa2",3);
      dots[visible*3]=0;
      if (count)
        CriketText(i,width/2,203,dots,0,0);
      else
        CriketText(i,width/2,201,"Введите пароль",2,0);
      if (str[count]=='_' && count) {
        int x=width/2+TextWidth(dots,strlen(dots))/2+4;
        XSetForeground(display,gcs[i],xcolor_foreground.pixel);
        XFillRectangle(display,frame,gcs[i],x,186,2,19);
      }
    } else {
      CriketText(i,width/2,201,str,2,warning);
    }
    CriketText(i,width/2,271,layout,2,caps);
XSetForeground(display,gcs[i],xcolor_foreground.pixel);
#ifdef HAVE_XFT_EXT
    XftDrawDestroy(xft_draws[i]);
    xft_draws[i]=window_draw;
#endif
    /* Present a complete frame once, without exposing the cleared background. */
    XCopyArea(display,frame,windows[i],gcs[i],0,0,width,height,0,0);
    XFreePixmap(display,frame);
  }
  XFlush(display);
}
