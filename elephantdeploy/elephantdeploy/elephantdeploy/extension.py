from os.path import dirname


def componentdefs():
    """
    Get the base path to the components definition directory.

    This is elephant's entry point for 'confab.extensions' in setup.py.
    Used by confab to find components templates and default data.
    Used by elmer to find components definition modules.
    """
    return dirname(__file__)
