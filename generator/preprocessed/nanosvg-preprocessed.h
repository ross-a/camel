enum NSVGpaintType {
NSVG_PAINT_NONE = 0,
NSVG_PAINT_COLOR = 1,
NSVG_PAINT_LINEAR_GRADIENT = 2,
NSVG_PAINT_RADIAL_GRADIENT = 3
};
enum NSVGspreadType {
NSVG_SPREAD_PAD = 0,
NSVG_SPREAD_REFLECT = 1,
NSVG_SPREAD_REPEAT = 2
};
enum NSVGlineJoin {
NSVG_JOIN_MITER = 0,
NSVG_JOIN_ROUND = 1,
NSVG_JOIN_BEVEL = 2
};
enum NSVGlineCap {
NSVG_CAP_BUTT = 0,
NSVG_CAP_ROUND = 1,
NSVG_CAP_SQUARE = 2
};
enum NSVGfillRule {
NSVG_FILLRULE_NONZERO = 0,
NSVG_FILLRULE_EVENODD = 1
};
enum NSVGflags {
NSVG_FLAGS_VISIBLE = 0x01
};
typedef struct NSVGgradientStop {
unsigned int color;
float offset;
} NSVGgradientStop;
typedef struct NSVGgradient {
float xform[6];
char spread;
float fx, fy;
int nstops;
NSVGgradientStop stops[1];
} NSVGgradient;
typedef struct NSVGpaint {
char type;
union {
unsigned int color;
NSVGgradient* gradient;
};
} NSVGpaint;
typedef struct NSVGpath
{
float* pts;
int npts;
char closed;
float bounds[4];
struct NSVGpath* next;
} NSVGpath;
typedef struct NSVGshape
{
char id[64];
char parent_id[64];
NSVGpaint fill;
NSVGpaint stroke;
float opacity;
float strokeWidth;
float strokeDashOffset;
float strokeDashArray[8];
char strokeDashCount;
char strokeLineJoin;
char strokeLineCap;
float miterLimit;
char fillRule;
unsigned char flags;
float bounds[4];
NSVGpath* paths;
struct NSVGshape* next;
} NSVGshape;
typedef struct NSVGref
{
char ref[64];
struct NSVGref* next;
} NSVGref;
typedef struct NSVGuse
{
char label[64];
NSVGref* refs;
struct NSVGuse* next;
} NSVGuse;
typedef struct NSVGimage
{
float width;
float height;
NSVGshape* shapes;
NSVGuse* uses;
} NSVGimage;
NSVGimage* nsvgParseFromFile(const char* filename, const char* units, float dpi);
NSVGimage* nsvgParse(char* input, const char* units, float dpi);
NSVGpath* nsvgDuplicatePath(NSVGpath* p);
void nsvgDelete(NSVGimage* image);
void nsvgRefsBounds(NSVGimage* image, NSVGref* refs, float* bounds);
typedef struct NSVGrasterizer NSVGrasterizer;
NSVGrasterizer* nsvgCreateRasterizer();
void nsvgRasterize(NSVGrasterizer* r,
NSVGimage* image, float tx, float ty, float scale,
unsigned char* dst, int w, int h, int stride);
void nsvgDeleteRasterizer(NSVGrasterizer*);
