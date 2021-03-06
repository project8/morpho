'''
JSON/Yaml IO processors
Authors: M. Guigue
Date: 06/26/18
'''

from __future__ import absolute_import

# import json as mymodule
import importlib
import os

from morpho.processors.IO import IOProcessor
from morpho.utilities import morphologging
logger = morphologging.getLogger(__name__)

__all__ = []
__all__.append(__name__)


class IOJSONProcessor(IOProcessor):
    '''
    Base IO JSON Processor

    Parameters:
        filename (required): path/name of file
        variables (required): variables to extract
        action: read or write (default="read")

    Input:
        None

    Results:
        data: dictionary containing the data
    '''

    module_name = 'json'
    dump_kwargs = {"indent": 4}

    def __init__(self, name):
        super().__init__(name)
        self.my_module = importlib.import_module(self.module_name)

    def Reader(self):
        logger.debug("Reading {}".format(self.file_name))
        if os.path.exists(self.file_name):
            with open(self.file_name, 'r') as json_file:
                try:
                    theData = self.my_module.load(json_file)
                except:
                    logger.error(
                        "Error while reading {}".format(self.file_name))
                    raise
        else:
            logger.error("File {} does not exist".format(self.file_name))
            raise FileNotFoundError(self.file_name)

        logger.debug("Extracting {}".format(self.variables))
        for var in self.variables:
            if var in theData.keys():
                self.data.update({str(var): theData[var]})
            else:
                logger.error("Variable {} does not exist in {}".format(
                    var, self.file_name))
                return False
        return True

    def Writer(self):
        logger.debug("Saving data in {}".format(self.file_name))
        rdir = os.path.dirname(self.file_name)
        if rdir != '' and not os.path.exists(rdir):
            os.makedirs(rdir)
            logger.debug("Creating folder: {}".format(rdir))
        logger.debug("Extracting {}".format(self.variables))
        subData = {}
        for item in self.variables:
            if isinstance(item, str):
                alias = item
                var = item
                subData.update({str(alias): self.data[var]})
            elif isinstance(item, dict) and 'variable' in item.keys() and item['variable'] in self.data.keys():
                var = str(item['variable'])
                if "json_alias" in item:
                    alias = str(item.get("json_alias"))
                else:
                    alias = var
                subData.update({str(alias): self.data[var]})
            else:
                logger.error("Variable {} does not exist in {}".format(
                    self.variables, self.file_name))
                return False
        with open(self.file_name, 'w') as json_file:
            try:
                self.my_module.dump(subData, json_file, **self.dump_kwargs)
            except:
                logger.error("Error while writing {}".format(self.file_name))
                raise
        logger.debug("File saved!")
        return True


class IOYAMLProcessor(IOJSONProcessor):
    '''
    IO YAML Processor: uses IOJSONProcessor as basis

    Parameters:
        filename (required): path/name of file
        variables (required): variables to extract
        action: read or write (default="read")

    Input:
        None

    Results:
        data: dictionary containing the data
    '''

    module_name = 'yaml'
