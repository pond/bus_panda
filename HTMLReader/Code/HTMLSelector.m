//  HTMLSelector.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

// Implements CSS Selectors Level 3 http://www.w3.org/TR/css3-selectors/

#import "HTMLSelector.h"
#import "HTMLTextNode.h"

typedef BOOL (^HTMLSelectorPredicate)(HTMLElement *node);
typedef HTMLSelectorPredicate HTMLSelectorPredicateGen;

static HTMLSelectorPredicate SelectorFunctionForString(NSString *selectorString, NSError **error);

static NSError * ParseError(NSString *reason, NSString *string, NSUInteger position)
{
    /*
	 String that looks like
	 
	 Error near character 4: Pseudo elements unsupported
     tag::
        ^
     
     */
    NSString *caretString = [@"^" stringByPaddingToLength:position+1 withString:@" " startingAtIndex:0];
    NSString *failureReason = [NSString stringWithFormat:@"Error near character %zd: %@\n\n\t%@\n\t\%@",
                               position,
                               reason,
                               string,
                               caretString];
    
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: reason,
                                NSLocalizedFailureReasonErrorKey: failureReason,
                                HTMLSelectorInputStringErrorKey: string,
                                HTMLSelectorLocationErrorKey: @(position),
                                };
    return [NSError errorWithDomain:HTMLSelectorErrorDomain code:1 userInfo:userInfo];
}

HTMLSelectorPredicateGen negatePredicate(HTMLSelectorPredicate predicate)
{
	if (!predicate) return nil;
	
	return ^BOOL(HTMLElement *node) {
		return !predicate(node);
	};
}

HTMLSelectorPredicateGen neverPredicate(void)
{
    return ^(HTMLElement *node) {
        return NO;
    };
}

#pragma mark - Combinators

HTMLSelectorPredicateGen bothCombinatorPredicate(HTMLSelectorPredicate a, HTMLSelectorPredicate b)
{
	// There was probably an error somewhere else in parsing, so return nil here
	if (!a || !b) return nil;
	
	return ^BOOL(HTMLElement *node) {
		return a(node) && b(node);
	};
}

HTMLSelectorPredicateGen andCombinatorPredicate(NSArray *predicates)
{
    return ^(HTMLElement *node) {
        for (HTMLSelectorPredicate predicate in predicates) {
            if (!predicate(node)) {
                return NO;
            }
        }
        return YES;
    };
}

HTMLSelectorPredicateGen orCombinatorPredicate(NSArray *predicates)
{
	return ^(HTMLElement *node) {
		for (HTMLSelectorPredicate predicate in predicates) {
			if (predicate(node)) {
				return YES;
			}
		}
		return NO;
	};
}

HTMLSelectorPredicateGen isTagTypePredicate(NSString *tagType)
{
	if ([tagType isEqualToString:@"*"]) {
		return ^(HTMLElement *node) {
            return YES;
        };
	} else {
		return ^BOOL(HTMLElement *node) {
			return [node.tagName compare:tagType options:NSCaseInsensitiveSearch] == NSOrderedSame;
		};
	}
}

HTMLSelectorPredicateGen childOfOtherPredicatePredicate(HTMLSelectorPredicate parentPredicate)
{
	if (!parentPredicate) return nil;
	
	return ^(HTMLElement *element) {
		return parentPredicate(element.parentElement);
	};
}

HTMLSelectorPredicateGen descendantOfPredicate(HTMLSelectorPredicate parentPredicate)
{
	if (!parentPredicate) return nil;
	
	return ^(HTMLElement *element) {
		HTMLElement *parent = element.parentElement;
		while (parent) {
			if (parentPredicate(parent)) {
				return YES;
			}
			parent = parent.parentElement;
		}
		return NO;
	};
}

HTMLSelectorPredicateGen isEmptyPredicate(void)
{
	return ^BOOL(HTMLElement *node) {
        for (HTMLNode *child in node.children) {
            if ([child isKindOfClass:[HTMLElement class]]) {
                return NO;
            } else if ([child isKindOfClass:[HTMLTextNode class]]) {
                HTMLTextNode *textNode = (HTMLTextNode *)child;
                if (textNode.data.length > 0) {
                    return NO;
                }
            }
        }
        return YES;
	};
}


#pragma mark - Attribute Predicates

HTMLSelectorPredicateGen hasAttributePredicate(NSString *attributeName)
{
	return ^BOOL(HTMLElement *node) {
		return !!node[attributeName];
	};
}

HTMLSelectorPredicateGen attributeIsExactlyPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElement *node) {
		return [node[attributeName] isEqualToString:attributeValue];
	};
}

NSCharacterSet * HTMLSelectorWhitespaceCharacterSet(void)
{
    // http://www.w3.org/TR/css3-selectors/#whitespace
    return [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r\f"];
}

HTMLSelectorPredicateGen attributeContainsExactWhitespaceSeparatedValuePredicate(NSString *attributeName, NSString *attributeValue)
{
    NSCharacterSet *whitespace = HTMLSelectorWhitespaceCharacterSet();
    return ^(HTMLElement *node) {
        NSArray *items = [node[attributeName] componentsSeparatedByCharactersInSet:whitespace];
        return [items containsObject:attributeValue];
    };
}

HTMLSelectorPredicateGen attributeStartsWithPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElement *node) {
		return [node[attributeName] hasPrefix:attributeValue];
	};
}

HTMLSelectorPredicateGen attributeContainsPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^BOOL(HTMLElement *node) {
        NSString *value = node[attributeName];
		return value && [value rangeOfString:attributeValue].location != NSNotFound;
	};
}

HTMLSelectorPredicateGen attributeEndsWithPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElement *node) {
		return [node[attributeName] hasSuffix:attributeValue];
	};
}

HTMLSelectorPredicateGen attributeIsExactlyAnyOf(NSString *attributeName, NSArray *attributeValues)
{
	NSMutableArray *arrayOfPredicates = [NSMutableArray arrayWithCapacity:attributeValues.count];
	for (NSString *attributeValue in attributeValues) {
		[arrayOfPredicates addObject:attributeIsExactlyPredicate(attributeName, attributeValue)];
	}
	return orCombinatorPredicate(arrayOfPredicates);
}

HTMLSelectorPredicateGen attributeStartsWithAnyOf(NSString *attributeName, NSArray *attributeValues)
{
	NSMutableArray *arrayOfPredicates = [NSMutableArray arrayWithCapacity:attributeValues.count];
	for (NSString *attributeValue in attributeValues) {
		[arrayOfPredicates addObject:attributeStartsWithPredicate(attributeName, attributeValue)];
	}
	return orCombinatorPredicate(arrayOfPredicates);
}

#pragma mark Sibling Predicates

HTMLSelectorPredicateGen adjacentSiblingPredicate(HTMLSelectorPredicate siblingTest)
{
	if (!siblingTest) return nil;
	
	return ^BOOL(HTMLElement *node) {
		NSArray *parentChildren = node.parentElement.childElementNodes;
		NSUInteger nodeIndex = [parentChildren indexOfObject:node];
		return nodeIndex != 0 && siblingTest([parentChildren objectAtIndex:nodeIndex - 1]);
	};
}

HTMLSelectorPredicateGen generalSiblingPredicate(HTMLSelectorPredicate siblingTest)
{
	if (!siblingTest) return nil;
	
	return ^(HTMLElement *node) {
		for (HTMLElement *sibling in node.parentElement.childElementNodes) {
			if ([sibling isEqual:node]) {
				break;
			}
			if (siblingTest(node)) {
				return YES;
			}
		}
		return NO;
	};
}

#pragma mark nth- Predicates

HTMLSelectorPredicateGen isNthChildPredicate(HTMLNthExpression nth, BOOL fromLast)
{
	return ^BOOL(HTMLNode *node) {
		NSArray *parentElements = node.parentElement.childElementNodes;
		// Index relative to start/end
		NSInteger nthPosition;
		if (fromLast) {
			nthPosition = parentElements.count - [parentElements indexOfObject:node];
		} else {
			nthPosition = [parentElements indexOfObject:node] + 1;
		}
        if (nth.n > 0) {
            return (nthPosition - nth.c) % nth.n == 0;
        } else {
            return nthPosition == nth.c;
        }
	};
}

HTMLSelectorPredicateGen isNthChildOfTypePredicate(HTMLNthExpression nth, HTMLSelectorPredicate typePredicate, BOOL fromLast)
{
	if (!typePredicate) return nil;
	
	return ^BOOL(HTMLElement *node) {
		id <NSFastEnumeration> enumerator = (fromLast
                                             ? node.parentElement.childElementNodes.reverseObjectEnumerator
                                             : node.parentElement.childElementNodes);
		NSInteger count = 0;
		for (HTMLElement *currentNode in enumerator) {
			if (typePredicate(currentNode)) {
				count++;
			}
			if ([currentNode isEqual:node]) {
				// check if the current node is the nth element of its type based on the current count
				if (nth.n > 0) {
					return (count - nth.c) % nth.n == 0;
				} else {
					return (count - nth.c) == 0;
				}
			}
		}
		return NO;
	};
}

HTMLSelectorPredicateGen isFirstChildPredicate(void)
{
	return isNthChildPredicate(HTMLNthExpressionMake(0, 1), NO);
}

HTMLSelectorPredicateGen isLastChildPredicate(void)
{
	return isNthChildPredicate(HTMLNthExpressionMake(0, 1), YES);
}

HTMLSelectorPredicateGen isFirstChildOfTypePredicate(HTMLSelectorPredicate typePredicate)
{
	return isNthChildOfTypePredicate(HTMLNthExpressionMake(0, 1), typePredicate, NO);
}

HTMLSelectorPredicateGen isLastChildOfTypePredicate(HTMLSelectorPredicate typePredicate)
{
	return isNthChildOfTypePredicate(HTMLNthExpressionMake(0, 1), typePredicate, YES);
}

#pragma mark Attribute Helpers

HTMLSelectorPredicateGen isKindOfClassPredicate(NSString *classname)
{
	return attributeContainsExactWhitespaceSeparatedValuePredicate(@"class", classname);
}

HTMLSelectorPredicateGen hasIDPredicate(NSString *idValue)
{
	return attributeIsExactlyPredicate(@"id", idValue);
}

HTMLSelectorPredicateGen isLinkPredicate(void)
{
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/selectors.html#selector-link
    return andCombinatorPredicate(@[orCombinatorPredicate(@[isTagTypePredicate(@"a"),
                                                            isTagTypePredicate(@"area"),
                                                            isTagTypePredicate(@"link")
                                                            ]),
                                    hasAttributePredicate(@"href")
                                    ]);
}

HTMLSelectorPredicateGen isDisabledPredicate(void)
{
    HTMLSelectorPredicateGen (*and)(NSArray *) = andCombinatorPredicate;
    HTMLSelectorPredicateGen (*or)(NSArray *) = orCombinatorPredicate;
    HTMLSelectorPredicateGen (*not)(HTMLSelectorPredicate) = negatePredicate;
    HTMLSelectorPredicate hasDisabledAttribute = hasAttributePredicate(@"disabled");
    
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/common-idioms.html#concept-element-disabled
    HTMLSelectorPredicate disabledOptgroup = and(@[isTagTypePredicate(@"optgroup"), hasDisabledAttribute]);
    HTMLSelectorPredicate disabledFieldset = and(@[isTagTypePredicate(@"fieldset"), hasDisabledAttribute]);
    HTMLSelectorPredicate disabledMenuitem = and(@[isTagTypePredicate(@"menuitem"), hasDisabledAttribute]);
    
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/association-of-controls-and-forms.html#concept-fe-disabled
    HTMLSelectorPredicate formElement = or(@[isTagTypePredicate(@"button"),
                                              isTagTypePredicate(@"input"),
                                              isTagTypePredicate(@"select"),
                                              isTagTypePredicate(@"textarea")
                                              ]);
    HTMLSelectorPredicate firstLegend = isFirstChildOfTypePredicate(isTagTypePredicate(@"legend"));
    HTMLSelectorPredicate firstLegendOfDisabledFieldset = and(@[firstLegend, descendantOfPredicate(disabledFieldset)]);
    HTMLSelectorPredicate disabledFormElement = and(@[formElement,
                                                      or(@[hasDisabledAttribute,
                                                           and(@[descendantOfPredicate(disabledFieldset),
                                                                 not(descendantOfPredicate(firstLegendOfDisabledFieldset))
                                                                 ])
                                                           ])
                                                      ]);
    
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/the-button-element.html#concept-option-disabled
    HTMLSelectorPredicate disabledOption = and(@[ isTagTypePredicate(@"option"),
                                                  or(@[ hasDisabledAttribute,
                                                        descendantOfPredicate(disabledOptgroup) ])
                                                  ]);
    
    return or(@[ disabledOptgroup, disabledFieldset, disabledMenuitem, disabledFormElement, disabledOption ]);
}

HTMLSelectorPredicateGen isEnabledPredicate(void)
{
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/selectors.html#selector-enabled
    HTMLSelectorPredicate hasHrefAttribute = hasAttributePredicate(@"href");
    HTMLSelectorPredicate enabledByHref = orCombinatorPredicate(@[isTagTypePredicate(@"a"),
                                                                  isTagTypePredicate(@"area"),
                                                                  isTagTypePredicate(@"link")
                                                                  ]);
    HTMLSelectorPredicate canOtherwiseBeEnabled = orCombinatorPredicate(@[isTagTypePredicate(@"button"),
                                                                          isTagTypePredicate(@"input"),
                                                                          isTagTypePredicate(@"select"),
                                                                          isTagTypePredicate(@"textarea"),
                                                                          isTagTypePredicate(@"optgroup"),
                                                                          isTagTypePredicate(@"option"),
                                                                          isTagTypePredicate(@"menuitem"),
                                                                          isTagTypePredicate(@"fieldset")
                                                                          ]);
    return orCombinatorPredicate(@[andCombinatorPredicate(@[enabledByHref, hasHrefAttribute ]),
                                   andCombinatorPredicate(@[canOtherwiseBeEnabled,
                                                            negatePredicate(isDisabledPredicate())
                                                            ])
                                   ]);
}

HTMLSelectorPredicateGen isCheckedPredicate(void)
{
	return orCombinatorPredicate(@[hasAttributePredicate(@"checked"), hasAttributePredicate(@"selected")]);
}

#pragma mark - Only Child

HTMLSelectorPredicateGen isOnlyChildPredicate(void)
{
	return ^BOOL(HTMLNode *node) {
		return [node.parentElement childElementNodes].count == 1;
	};
}

HTMLSelectorPredicateGen isOnlyChildOfTypePredicate(HTMLSelectorPredicate typePredicate)
{
	return bothCombinatorPredicate(isFirstChildOfTypePredicate(typePredicate), isLastChildOfTypePredicate(typePredicate));
}

HTMLSelectorPredicateGen isRootPredicate(void)
{
	return ^BOOL(HTMLElement *node)
	{
		return !node.parentElement;
	};
}

NSNumber * parseNumber(NSString *number, NSInteger defaultValue)
{
    // Strip whitespace so -isAtEnd check below answers "was this a valid integer?"
    number = [number stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
	NSScanner *scanner = [NSScanner scannerWithString:number];
    NSInteger result = defaultValue;
	[scanner scanInteger:&result];
    return scanner.isAtEnd ? @(result) : nil;
}

#pragma mark Parse

static NSString * scanFunctionInterior(NSScanner *scanner, NSError **error)
{
	BOOL ok;
    
    ok = [scanner scanString:@"(" intoString:nil];
	if (!ok) {
		if (error) *error = ParseError(@"Expected ( to start function", scanner.string, scanner.scanLocation);
		return nil;
	}
	
    NSString *interior;
	ok = [scanner scanUpToString:@")" intoString:&interior];
	if (!ok) {
		*error = ParseError(@"Expected ) to end function", scanner.string, scanner.scanLocation);
		return nil;
	}
    
    [scanner scanString:@")" intoString:nil];
	return interior;
}

static HTMLSelectorPredicateGen scanPredicateFromPseudoClass(NSScanner *scanner,
                                                             HTMLSelectorPredicate typePredicate,
                                                             NSError **error)
{
	typedef HTMLSelectorPredicate (^CSSThing)(HTMLNthExpression nth);
    BOOL ok;
    
	NSString *pseudo;
	
	// TODO Can't assume the end of the pseudo is the end of the string
	ok = [scanner scanUpToString:@"(" intoString:&pseudo];
	if (!ok && !scanner.isAtEnd) {
		pseudo = [scanner.string substringFromIndex:scanner.scanLocation];
		scanner.scanLocation = scanner.string.length - 1;
	}
	
	// Case-insensitively look for pseudo classes
	pseudo = [pseudo lowercaseString];
	
	static NSDictionary *simplePseudos = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        simplePseudos = @{
                          @"first-child": isFirstChildPredicate(),
                          @"last-child": isLastChildPredicate(),
                          @"only-child": isOnlyChildPredicate(),
                          
                          @"empty": isEmptyPredicate(),
                          @"root": isRootPredicate(),
                          
                          @"link": isLinkPredicate(),
                          @"visited": neverPredicate(),
                          @"active": neverPredicate(),
                          @"hover": neverPredicate(),
                          @"focus": neverPredicate(),
                          
                          @"enabled": isEnabledPredicate(),
                          @"disabled": isDisabledPredicate(),
                          @"checked": isCheckedPredicate()
                          };
	});
	
	id simple = simplePseudos[pseudo];
	if (simple) {
		return simple;
	}
	else if ([pseudo isEqualToString:@"first-of-type"]){
		return isFirstChildOfTypePredicate(typePredicate);
	}
	else if ([pseudo isEqualToString:@"last-of-type"]){
		return isLastChildOfTypePredicate(typePredicate);
	}
	else if ([pseudo isEqualToString:@"only-of-type"]){
		return isOnlyChildOfTypePredicate(typePredicate);
	}
	else if ([pseudo hasPrefix:@"nth"]) {
		NSString *interior = scanFunctionInterior(scanner, error);
		
		if (!interior) return nil;
		
		HTMLNthExpression nth = HTMLNthExpressionFromString(interior);
		
		if (HTMLNthExpressionEqualToNthExpression(nth, HTMLNthExpressionInvalid)) {
			*error = ParseError(@"Failed to parse Nth statement", scanner.string, scanner.scanLocation);
			return nil;
		}

		if ([pseudo isEqualToString:@"nth-child"]){
			return isNthChildPredicate(nth, NO);
		}
		else if ([pseudo isEqualToString:@"nth-last-child"]){
			return isNthChildPredicate(nth, YES);
		}
		else if ([pseudo isEqualToString:@"nth-of-type"]){
			return isNthChildOfTypePredicate(nth, typePredicate, NO);
		}
		else if ([pseudo isEqualToString:@"nth-last-of-type"]){
			return isNthChildOfTypePredicate(nth, typePredicate, YES);
		}
	}
	else if ([pseudo isEqualToString:@"not"]) {
		NSString *toNegateString = scanFunctionInterior(scanner, error);
		HTMLSelectorPredicate toNegate = SelectorFunctionForString(toNegateString, error);
		return negatePredicate(toNegate);
	}
	
	*error = ParseError(@"Unrecognized pseudo class", scanner.string, scanner.scanLocation);
	return nil;
}


#pragma mark

static NSCharacterSet *identifierCharacters()
{
    static NSCharacterSet *frozenSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithCharactersInString:@"-_"];
        [set formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        frozenSet = [set copy];
    });
	return frozenSet;
}

static NSCharacterSet *tagModifierCharacters()
{
	return [NSCharacterSet characterSetWithCharactersInString:@".:#["];
}

static NSCharacterSet *combinatorCharacters()
{
    static NSCharacterSet *frozenSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Combinators are: whitespace, "greater-than sign" (U+003E, >), "plus sign" (U+002B, +) and "tilde" (U+007E, ~)
        NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithCharactersInString:@">+~"];
        [set formUnionWithCharacterSet:HTMLSelectorWhitespaceCharacterSet()];
        frozenSet = [set copy];
    });
	return frozenSet;
}

NSString *scanIdentifier(NSScanner *scanner,  NSError **error)
{
	NSString *ident;
	[scanner scanCharactersFromSet:identifierCharacters() intoString:&ident];
	return [ident stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

NSString *scanTagModifier(NSScanner *scanner, NSError **error)
{
	NSString *modifier;
	[scanner scanCharactersFromSet:tagModifierCharacters() intoString:&modifier];
	modifier = [modifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	modifier = [modifier length] != 0 ? modifier : nil;
	return modifier;
}

NSString *scanCombinator(NSScanner *scanner,  NSError **error)
{
	NSString *operator;
	[scanner scanCharactersFromSet:combinatorCharacters() intoString:&operator];
	operator = [operator stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return operator;
}

HTMLSelectorPredicate scanAttributePredicate(NSScanner *scanner, NSError **error)
{
    NSCAssert([scanner.string characterAtIndex:scanner.scanLocation - 1] == '[', nil);
    
	NSString *attributeName = scanIdentifier(scanner, error);
	NSString *operator;
    NSString *attributeValue;
    BOOL ok;
    [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"=]"]
                            intoString:&operator];
    ok = [scanner scanString:@"=" intoString:nil];
    if (ok) {
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
		operator = [operator stringByTrimmingCharactersInSet:whitespace];
        operator = operator.length > 0 ? operator : @"=";
        [scanner scanCharactersFromSet:whitespace intoString:nil];
        attributeValue = scanIdentifier(scanner, error);
        if (!attributeValue) {
            [scanner scanCharactersFromSet:whitespace intoString:nil];
            NSString *quote = [scanner.string substringWithRange:NSMakeRange(scanner.scanLocation, 1)];
            if (!([quote isEqualToString:@"\""] || [quote isEqualToString:@"'"])) {
				*error = ParseError(@"Expected quote in attribute value", scanner.string, scanner.scanLocation);
                return nil;
            }
            [scanner scanString:quote intoString:nil];
            [scanner scanUpToString:quote intoString:&attributeValue];
            [scanner scanString:quote intoString:nil];
        }
    } else {
        operator = nil;
    }
	
	[scanner scanUpToString:@"]" intoString:nil];
	ok = [scanner scanString:@"]" intoString:nil];
	if (!ok) {
		*error = ParseError(@"Expected ] to close attribute", scanner.string, scanner.scanLocation);
		return nil;
	}
	
	if ([operator length] == 0) {
		return hasAttributePredicate(attributeName);
	} else if ([operator isEqualToString:@"="]) {
		return attributeIsExactlyPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"~"]) {
        return attributeContainsExactWhitespaceSeparatedValuePredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"^"]) {
		return attributeStartsWithPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"$"]) {
		return attributeEndsWithPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"*"]) {
		return attributeContainsPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"|"]) {
		return orCombinatorPredicate(@[attributeIsExactlyPredicate(attributeName, attributeValue),
                                       attributeStartsWithPredicate(attributeName, [attributeValue stringByAppendingString:@"-"])]);
	} else {
		*error = ParseError(@"Unexpected operator", scanner.string, scanner.scanLocation - operator.length);
		return nil;
	}
}

HTMLSelectorPredicateGen scanTagPredicate(NSScanner *scanner, NSError **error)
{
	NSString *identifier = scanIdentifier(scanner, error);
	if (identifier) {
        return isTagTypePredicate(identifier);
    } else {
        [scanner scanString:@"*" intoString:nil];
        return isTagTypePredicate(@"*");
    }
}


HTMLSelectorPredicateGen scanPredicate(NSScanner *scanner, HTMLSelectorPredicate inputPredicate, NSError **error)
{
	HTMLSelectorPredicate tagPredicate = scanTagPredicate(scanner, error);
	
	inputPredicate = inputPredicate ? bothCombinatorPredicate(tagPredicate, inputPredicate) : tagPredicate;
	
	// If we're out of things to scan, all we have is this tag, no operators on it
	if (scanner.isAtEnd) return inputPredicate;
	
	NSString *modifier;
	
	do {
		modifier = scanTagModifier(scanner, error);
		
		// Pseudo and attribute
		if ([modifier isEqualToString:@":"]) {
			inputPredicate = bothCombinatorPredicate(inputPredicate,
													 scanPredicateFromPseudoClass(scanner, inputPredicate, error));
		} else if ([modifier isEqualToString:@"::"]) {
			// We don't support *any* pseudo-elements.
			*error = ParseError(@"Pseudo elements unsupported", scanner.string, scanner.scanLocation - modifier.length);
			return nil;
		} else if ([modifier isEqualToString:@"["]) {
			inputPredicate = bothCombinatorPredicate(inputPredicate,
													 scanAttributePredicate(scanner, error));
		} else if ([modifier isEqualToString:@"."]) {
			NSString *className = scanIdentifier(scanner, error);
			inputPredicate =  bothCombinatorPredicate(inputPredicate,
                                                      isKindOfClassPredicate(className));
		} else if ([modifier isEqualToString:@"#"]) {
			NSString *idName = scanIdentifier(scanner, error);
			inputPredicate =  bothCombinatorPredicate(inputPredicate,
                                                      hasIDPredicate(idName));
		} else if (modifier != nil) {
			*error = ParseError(@"Unexpected modifier", scanner.string, scanner.scanLocation - modifier.length);
			return nil;
		}
		
	} while (modifier != nil);
	

	
	// Pseudo and attribute cases require that this is either the end of the selector, or there's another combinator after them
	
	if (scanner.isAtEnd) return inputPredicate;
	
	NSString *combinator = scanCombinator(scanner, error);
	
	if ([combinator isEqualToString:@""]) {
		// Whitespace combinator: y descendant of an x
		return descendantOfPredicate(inputPredicate);
	} else if ([combinator isEqualToString:@">"]) {
		return childOfOtherPredicatePredicate(inputPredicate);
	} else if ([combinator isEqualToString:@"+"]) {
		return adjacentSiblingPredicate(inputPredicate);
	} else if ([combinator isEqualToString:@"~"]) {
		return generalSiblingPredicate(inputPredicate);
	}
    
	if (combinator == nil) {
		*error = ParseError(@"Expected a combinator here", scanner.string, scanner.scanLocation);
		return nil;
	} else {
		*error = ParseError(@"Unexpected combinator", scanner.string, scanner.scanLocation - combinator.length);
		return nil;
	}
}

static HTMLSelectorPredicate SelectorFunctionForString(NSString *selectorString, NSError **error)
{
	// Trim non-functional whitespace
	selectorString = [selectorString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // An empty selector is an invalid selector.
    if (selectorString.length == 0) {
        if (error) *error = ParseError(@"Empty selector", selectorString, 0);
        return nil;
    }
	
	NSScanner *scanner = [NSScanner scannerWithString:selectorString];
    scanner.caseSensitive = NO; // Section 3 states that in HTML parsing, selectors are case-insensitive
    scanner.charactersToBeSkipped = nil;
	
	// Scan out predicate parts and combine them
	HTMLSelectorPredicate lastPredicate = nil;
	
	do {
		lastPredicate = scanPredicate(scanner, lastPredicate, error);
	} while (lastPredicate && ![scanner isAtEnd] && !*error);
	
	NSCAssert(lastPredicate || *error, @"Need either a predicate or error at this point");
	
	return lastPredicate;
}

@interface HTMLSelector ()

@property (copy, nonatomic) NSString *string;
@property (strong, nonatomic) NSError *error;
@property (copy, nonatomic) HTMLSelectorPredicate predicate;

// http://stackoverflow.com/questions/32741123/objective-c-warning-method-override-for-the-designated-initializer-of-the-superc
- (instancetype) init NS_DESIGNATED_INITIALIZER;
@end

@implementation HTMLSelector

// http://stackoverflow.com/questions/32741123/objective-c-warning-method-override-for-the-designated-initializer-of-the-superc
- (instancetype)init { @throw nil; }

+ (instancetype)selectorForString:(NSString *)selectorString
{
	return [[self alloc] initWithString:selectorString];
}

- (instancetype)initWithString:(NSString *)selectorString
{
    if ((self = [super init])) {
        _string = [selectorString copy];
        NSError *error;
        _predicate = SelectorFunctionForString(selectorString, &error);
        _error = error;
    }
    return self;
}

- (BOOL)matchesElement:(HTMLElement *)element
{
    return self.predicate(element);
}

- (NSString *)description
{
    if (self.error) {
        return [NSString stringWithFormat:@"<%@: %p ERROR: '%@'>", self.class, self, self.error];
    } else {
        return [NSString stringWithFormat:@"<%@: %p '%@'>", self.class, self, self.string];
	}
}

@end

NSString * const HTMLSelectorErrorDomain = @"HTMLSelectorErrorDomain";

NSString * const HTMLSelectorInputStringErrorKey = @"HTMLSelectorInputString";

NSString * const HTMLSelectorLocationErrorKey = @"HTMLSelectorLocation";

@implementation HTMLNode (HTMLSelector)

- (NSArray *)nodesMatchingSelector:(NSString *)selectorString
{
	return [self nodesMatchingParsedSelector:[HTMLSelector selectorForString:selectorString]];
}

- (HTMLElement *)firstNodeMatchingSelector:(NSString *)selectorString
{
    return [self firstNodeMatchingParsedSelector:[HTMLSelector selectorForString:selectorString]];
}

- (NSArray *)nodesMatchingParsedSelector:(HTMLSelector *)selector
{
	NSAssert(!selector.error, @"Attempted to use selector with error: %@", selector.error);
    
	NSMutableArray *ret = [NSMutableArray new];
	for (HTMLElement *node in self.treeEnumerator) {
		if ([node isKindOfClass:[HTMLElement class]] && [selector matchesElement:node]) {
			[ret addObject:node];
		}
	}
	return ret;
}

- (HTMLElement *)firstNodeMatchingParsedSelector:(HTMLSelector *)selector
{
    NSAssert(!selector.error, @"Attempted to use selector with error: %@", selector.error);
    
    for (HTMLElement *node in self.treeEnumerator) {
        if ([node isKindOfClass:[HTMLElement class]] && [selector matchesElement:node]) {
            return node;
        }
    }
    return nil;
}

@end

HTMLNthExpression HTMLNthExpressionMake(NSInteger n, NSInteger c)
{
    return (HTMLNthExpression){ .n = n, .c = c };
}

BOOL HTMLNthExpressionEqualToNthExpression(HTMLNthExpression a, HTMLNthExpression b)
{
    return a.n == b.n && a.c == b.c;
}

HTMLNthExpression HTMLNthExpressionFromString(NSString *string)
{
	string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([string compare:@"odd" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		return HTMLNthExpressionOdd;
	} else if ([string compare:@"even" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		return HTMLNthExpressionEven;
	} else {
        NSCharacterSet *nthCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789 nN+-"] invertedSet];
        if ([string rangeOfCharacterFromSet:nthCharacters].location != NSNotFound) {
            return HTMLNthExpressionInvalid;
        }
	}
	
	NSArray *valueSplit = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"nN"]];
	
	if (valueSplit.count == 0 || valueSplit.count > 2) {
		// No Ns or multiple Ns, fail
		return HTMLNthExpressionInvalid;
	} else if (valueSplit.count == 2) {
		NSNumber *numberOne = parseNumber(valueSplit[0], 1);
		NSNumber *numberTwo = parseNumber(valueSplit[1], 0);
		
		if ([valueSplit[0] isEqualToString:@"-"] && numberTwo) {
			// "n" was defined, and only "-" was given as a multiplier
			return HTMLNthExpressionMake(-1, numberTwo.integerValue);
		} else if (numberOne && numberTwo) {
			return HTMLNthExpressionMake(numberOne.integerValue, numberTwo.integerValue);
		} else {
			return HTMLNthExpressionInvalid;
		}
	} else {
		NSNumber *number = parseNumber(valueSplit[0], 1);
		
		// "n" not found, use whole string as b
		return HTMLNthExpressionMake(0, number.integerValue);
	}
}

const HTMLNthExpression HTMLNthExpressionOdd = (HTMLNthExpression){ .n = 2, .c = 1 };

const HTMLNthExpression HTMLNthExpressionEven = (HTMLNthExpression){ .n = 2, .c = 0 };

const HTMLNthExpression HTMLNthExpressionInvalid = (HTMLNthExpression){ .n = 0, .c = 0 };
