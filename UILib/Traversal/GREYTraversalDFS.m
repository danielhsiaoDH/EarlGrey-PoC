//
// Copyright 2017 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "GREYTraversalDFS.h"

#import "GREYThrowDefines.h"
#import "CGGeometry+GREYUI.h"
#import "GREYTraversalFunctions.h"
#import "GREYTraversalObject.h"

@implementation GREYTraversalDFS {
  /**
   *  An array that contains the unrolled hierarchy.
   */
  NSMutableArray *_parsedHierarchy;

  /**
   *  NSUInteger to keep track of the index that is being accessed in the @c _parsedHierarchy array.
   */
  NSUInteger _parsedHierarchyIndex;

  /**
   *  Flag to indicate whether the hierarchy should be reversed or not. Default is @c YES.
   */
  BOOL _isBackToFront;

  /**
   *  Flag to indicate whether the hierarchy should be ordered by @c zPosition amongst sibling
   *  views.
   */
  BOOL _zOrdering;
}

- (instancetype)init:(id)element {
  self = [super init];
  if (self) {
    _parsedHierarchy = [[NSMutableArray alloc] init];
    _parsedHierarchyIndex = 0;
    [_parsedHierarchy addObject:element];
  }
  return self;
}

+ (instancetype)frontToBackHierarchyForElementWithDFSTraversal:(id)element {
  GREYThrowOnNilParameter(element);

  // Wrap the @c element in the GREYTraversalDFSObject.
  GREYTraversalObject *object = [[GREYTraversalObject alloc] init];
  object.level = 0;
  object.element = element;
  object.boundingRect = CGRectNull;

  // Create an instance of GREYTraversalDFS.
  return [[GREYTraversalDFS alloc] init:object];
}

+ (instancetype)backToFrontHierarchyForElementWithDFSTraversal:(id)element
                                                     zOrdering:(BOOL)zOrdering {
  GREYTraversalDFS *instance = [self frontToBackHierarchyForElementWithDFSTraversal:element];
  instance->_isBackToFront = YES;
  instance->_zOrdering = zOrdering;
  return instance;
}

- (id)nextObject {
  GREYTraversalObject *element = [self grey_nextObjectDFS];
  return element.element;
}

- (void)enumerateUsingBlock:(void (^)(id element, NSUInteger level, CGRect boundingRect,
                                      BOOL *stop))block {
  GREYThrowOnNilParameter(block);

  // Loop till we have explored each element in the hierarchy.
  GREYTraversalObject *object;
  BOOL stop = NO;
  while (!stop && (object = [self grey_nextObjectDFS])) {
    // For each element call the @c block.
    block(object.element, object.level, object.boundingRect, &stop);
  }
}

#pragma mark - Private

/**
 *  The method retrieves the next object in the hierarchy.
 *
 *  @return Returns an instance of GREYTraversalDFSObject.
 */
- (GREYTraversalObject *)grey_nextObjectDFS {
  // If we have explored all elements.
  if (_parsedHierarchyIndex >= [_parsedHierarchy count]) {
    return nil;
  }

  GREYTraversalObject *nextObject = [_parsedHierarchy objectAtIndex:_parsedHierarchyIndex];

  // For the DFS algorithm, we will add to the @c _parsedHierarchy array in a specified order,
  // and we also need to wrap the UI elements into GREYHierarchyObject instance.
  NSArray<id> *children = GREYTraversalExploreImmediateChildren(nextObject.element, _zOrdering);

  // Insert the GREYHierarchyObject instance into the front of the array. Here the array is used
  // as a stack, hence front insertions. We could have inserted into the back, however the logic
  // associated with @c _parsedHierarchyIndex facilitated front insertions.
  for (id child in _isBackToFront ? children : [children reverseObjectEnumerator]) {
    GREYTraversalObject *object = [[GREYTraversalObject alloc] init];
    [object setLevel:nextObject.level + 1];
    [object setElement:child];
    [object setBoundingRect:CGRectNull];

    // This updates the bounding area of each traversal object.
    // If the parent view's clipsToBound is set to YES, update the bounding area applying
    // the parent view's frame. Otherwise, pass down the current view's bounding area.
    // The bounding rect should be converted to the current view's coordinate space.
    if ([nextObject.element isKindOfClass:[UIView class]]) {
      UIView *parent = (UIView *)nextObject.element;
      CGRect convertedBoundingRect = [[parent superview] convertRect:nextObject.boundingRect
                                                              toView:parent];
      CGRect convertedParentRect = [[parent superview] convertRect:parent.frame toView:parent];
      if (![parent superview]) {
        object.boundingRect = CGRectNull;
      } else if ([parent clipsToBounds]) {
        if (CGRectEqualToRect(nextObject.boundingRect, CGRectNull)) {
          // If there's currently no boundingRect, update it to parent's frame.
          object.boundingRect = convertedParentRect;
        } else {
          CGRect intersectionRect =
              CGRectIntersectionStrict(convertedBoundingRect, convertedParentRect);
          if (CGRectIsNull(intersectionRect)) {
            // If the boundingRect does not intersect with parent's frame, boundingRect stays the
            // same as parent view would be clipped in the boundingRect.
            object.boundingRect = convertedBoundingRect;
          } else {
            object.boundingRect = intersectionRect;
          }
        }
      } else {
        // If parent does not clip, pass down boundingRect.
        object.boundingRect = convertedBoundingRect;
      }
    }
    [_parsedHierarchy insertObject:object atIndex:0];
  }

  // Retain the @c nextObject since we are removing it from the array.
  GREYTraversalObject *element = nextObject;
  [_parsedHierarchy removeObject:nextObject];
  return element;
}

@end