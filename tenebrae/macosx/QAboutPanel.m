//----------------------------------------------------------------------------------------------------------------------------
//
// "QAboutPanel.m"
//
// Written by:	Axel 'awe' Wefers			[mailto:awe@fruitz-of-dojo.de].
//				©2001-2012 Fruitz Of Dojo 	[http://www.fruitz-of-dojo.de].
//
//----------------------------------------------------------------------------------------------------------------------------

#import "QAboutPanel.h"
#import "QController.h"
#import "QShared.h"

#import <FruitzOfDojo/FruitzOfDojo.h>

//----------------------------------------------------------------------------------------------------------------------------

@implementation QAboutPanel

- (NSString *) nibName
{
	return @"AboutPanel";
}

//----------------------------------------------------------------------------------------------------------------------------

- (void) awakeFromNib
{
    [mLinkView setURL: [NSURL URLWithString: FRUITZ_OF_DOJO_URL]];
    [mOptionCheckBox setState: [[FDPreferences sharedPrefs] boolForKey: QUAKE_PREFS_KEY_OPTION_KEY]];
    [self setTitle: @"About"];
}

//----------------------------------------------------------------------------------------------------------------------------

- (NSString*) toolbarIdentifier
{
    return @"Quake About ToolbarItem";
}

//----------------------------------------------------------------------------------------------------------------------------

- (NSToolbarItem*) toolbarItem
{
	NSImage	* aboutImg	= [[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode(kToolbarInfoIcon)];
    NSToolbarItem* item = [super toolbarItem];
    
    [item setLabel: @"About"];
    [item setPaletteLabel: @"About"];
    [item setToolTip: @"About Quake."];
    [item setImage: aboutImg];
    
    return item;
}

//----------------------------------------------------------------------------------------------------------------------------

- (IBAction) toggleOptionCheckbox: (id) sender
{
    FD_UNUSED (sender);
    
    [[FDPreferences sharedPrefs] setObject: mOptionCheckBox forKey: QUAKE_PREFS_KEY_OPTION_KEY];
}

@end

//----------------------------------------------------------------------------------------------------------------------------
