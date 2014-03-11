/* -*- c-style: gnu -*-

   Copyright (c) 2014 John Harper <jsh@unfactored.org>

   Permission is hereby granted, free of charge, to any person
   obtaining a copy of this software and associated documentation files
   (the "Software"), to deal in the Software without restriction,
   including without limitation the rights to use, copy, modify, merge,
   publish, distribute, sublicense, and/or sell copies of the Software,
   and to permit persons to whom the Software is furnished to do so,
   subject to the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. */

#import "MgRectNode.h"

#import "MgCoderExtensions.h"
#import "MgCoreGraphics.h"
#import "MgDrawableNodeInternal.h"
#import "MgLayerNode.h"
#import "MgNodeInternal.h"

#import <Foundation/Foundation.h>

@implementation MgRectNode
{
  CGPathDrawingMode _drawingMode;
  id _fillColor;			/* CGColorRef */
  id _strokeColor;			/* CGColorref */
  CGFloat _lineWidth;
}

- (id)init
{
  self = [super init];
  if (self == nil)
    return nil;

  _drawingMode = kCGPathFill;
  _fillColor = (__bridge id)MgBlackColor();
  _strokeColor = (__bridge id)MgBlackColor();
  _lineWidth = 1;

  return self;
}

+ (BOOL)automaticallyNotifiesObserversOfDrawingMode
{
  return NO;
}

- (CGPathDrawingMode)drawingMode
{
  return _drawingMode;
}

- (void)setDrawingMode:(CGPathDrawingMode)x
{
  if (_drawingMode != x)
    {
      [self willChangeValueForKey:@"drawingMode"];
      _drawingMode = x;
      [self incrementVersion];
      [self didChangeValueForKey:@"drawingMode"];
    }
}

+ (BOOL)automaticallyNotifiesObserversOfFillColor
{
  return NO;
}

- (CGColorRef)fillColor
{
  return (__bridge CGColorRef)_fillColor;
}

- (void)setFillColor:(CGColorRef)x
{
  if (_fillColor != (__bridge id)x)
    {
      [self willChangeValueForKey:@"fillColor"];
      _fillColor = (__bridge id)x;
      [self incrementVersion];
      [self didChangeValueForKey:@"fillColor"];
    }
}

+ (BOOL)automaticallyNotifiesObserversOfStrokeColor
{
  return NO;
}

- (CGColorRef)strokeColor
{
  return (__bridge CGColorRef)_strokeColor;
}

- (void)setStrokeColor:(CGColorRef)x
{
  if (_strokeColor != (__bridge id)x)
    {
      [self willChangeValueForKey:@"strokeColor"];
      _strokeColor = (__bridge id)x;
      [self incrementVersion];
      [self didChangeValueForKey:@"strokeColor"];
    }
}

+ (BOOL)automaticallyNotifiesObserversOfLineWidth
{
  return NO;
}

- (CGFloat)lineWidth
{
  return _lineWidth;
}

- (void)setLineWidth:(CGFloat)x
{
  if (_lineWidth != x)
    {
      [self willChangeValueForKey:@"lineWidth"];
      _lineWidth = x;
      [self incrementVersion];
      [self didChangeValueForKey:@"lineWidth"];
    }
}

- (BOOL)containsPoint:(CGPoint)p layerNode:(MgLayerNode *)node
{
  /* FIXME: rounded corners. */

  return node != nil && CGRectContainsPoint(node.bounds, p);
}

- (void)_renderWithState:(MgDrawableRenderState *)rs
{
  if (rs->layer == nil)
    return;

  CGContextSaveGState(rs->ctx);

  CGContextSetBlendMode(rs->ctx, self.blendMode);
  CGContextSetAlpha(rs->ctx, rs->alpha * self.alpha);

  CGFloat radius = rs->layer.cornerRadius;
  CGPathDrawingMode mode = self.drawingMode;

  if (radius == 0 && (mode == kCGPathFill || mode == kCGPathEOFill))
    {
      CGContextSetFillColorWithColor(rs->ctx, self.fillColor);
      CGContextFillRect(rs->ctx, rs->layer.bounds);
    }
  else if (radius == 0 && mode == kCGPathStroke)
    {
      CGContextSetStrokeColorWithColor(rs->ctx, self.strokeColor);
      CGContextStrokeRectWithWidth(rs->ctx, rs->layer.bounds, self.lineWidth);
    }
  else
    {
      CGContextSetFillColorWithColor(rs->ctx, self.fillColor);
      CGContextSetStrokeColorWithColor(rs->ctx, self.strokeColor);
      CGContextSetLineWidth(rs->ctx, self.lineWidth);

      CGContextBeginPath(rs->ctx);
      if (radius == 0)
	CGContextAddRect(rs->ctx, rs->layer.bounds);
      else
	{
	  CGPathRef p = MgPathCreateWithRoundRect(rs->layer.bounds, radius);
	  CGContextAddPath(rs->ctx, p);
	  CGPathRelease(p);
	}

      CGContextDrawPath(rs->ctx, self.drawingMode);
    }

  CGContextRestoreGState(rs->ctx);
}

- (void)_renderMaskWithState:(MgDrawableRenderState *)rs
{
  if (rs->layer == nil)
    return;

  CGPathDrawingMode mode = self.drawingMode;

  float alpha = rs->alpha * self.alpha;

  if (alpha != 1
      || (mode != kCGPathStroke
	  && CGColorGetAlpha(self.fillColor) < 1)
      || (mode != kCGPathFill && mode != kCGPathEOFill
	  && CGColorGetAlpha(self.strokeColor) < 1))
    {
      [super _renderMaskWithState:rs];
      return;
    }

  CGFloat radius = rs->layer.cornerRadius;

  if (radius == 0 && (mode == kCGPathFill || mode == kCGPathEOFill))
    {
      CGContextClipToRect(rs->ctx, rs->layer.bounds);
      return;
    }

  CGPathRef p = MgPathCreateWithRoundRect(rs->layer.bounds, radius);
  CGPathRef sp = NULL;
  if (mode != kCGPathFill && mode != kCGPathEOFill)
    {
      sp = CGPathCreateCopyByStrokingPath(p, NULL, self.lineWidth,
					kCGLineCapButt, kCGLineJoinMiter, 10);
    }

  CGContextBeginPath(rs->ctx);
  CGContextAddPath(rs->ctx, p);
  if (sp != NULL)
    CGContextAddPath(rs->ctx, sp);
  CGContextClip(rs->ctx);

  CGPathRelease(sp);
  CGPathRelease(p);
}

/** NSCopying methods. **/

- (id)copyWithZone:(NSZone *)zone
{
  MgRectNode *copy = [super copyWithZone:zone];

  copy->_drawingMode = _drawingMode;
  copy->_fillColor = _fillColor;
  copy->_strokeColor = _strokeColor;
  copy->_lineWidth = _lineWidth;

  return copy;
}

/** NSCoding methods. **/

- (void)encodeWithCoder:(NSCoder *)c
{
  [super encodeWithCoder:c];

  if (_drawingMode != kCGPathFill)
    [c encodeInt:_drawingMode forKey:@"drawingMode"];

  if (_fillColor != nil)
    [c mg_encodeCGColor:(__bridge CGColorRef)_fillColor forKey:@"fillColor"];

  if (_strokeColor != nil)
    [c mg_encodeCGColor:(__bridge CGColorRef)_strokeColor forKey:@"strokeColor"];

  if (_lineWidth != 1)
    [c encodeDouble:_lineWidth forKey:@"lineWidth"];
}

- (id)initWithCoder:(NSCoder *)c
{
  self = [super initWithCoder:c];
  if (self == nil)
    return nil;

  if ([c containsValueForKey:@"drawingMode"])
    _drawingMode = (CGPathDrawingMode)[c decodeIntForKey:@"drawingMode"];
  else
    _drawingMode = kCGPathFill;

  if ([c containsValueForKey:@"fillColor"])
    _fillColor = (__bridge id)[c mg_decodeCGColorForKey:@"fillColor"];

  if ([c containsValueForKey:@"strokeColor"])
    _strokeColor = (__bridge id)[c mg_decodeCGColorForKey:@"strokeColor"];

  if ([c containsValueForKey:@"lineWidth"])
    _lineWidth = [c decodeDoubleForKey:@"lineWidth"];
  else
    _lineWidth = 1;

  return self;
}

@end
