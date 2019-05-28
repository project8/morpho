'''
A super simple module for unittest
'''

from math import sin
from morpho.utilities import morphologging
logger = morphologging.getLogger(__name__)


def myFunction(x, a, b):
    # logger.info("This is my function: {},{},{} -> {}".format(x,a,b,abs(a*sin(b*x))))
    return abs(a*sin(b*x))
