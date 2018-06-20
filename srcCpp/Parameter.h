#ifndef __PARAMETER_H__
#define __PARAMETER_H__

/*
 * (c) 2005-2018  Copyright, Real-Time Innovations, Inc. All rights reserved.
 * Subject to Eclipse Public License v1.0; see LICENSE.md for details.
 */


#include <stdio.h>
#include <climits>
#include <string>
#include <utility>      // std::pair, std::make_pair
#include <vector>
#include <iostream>
#include <sstream>

enum TYPE {
    T_NULL,           // Default type
    T_NUMERIC,        // Numeric type, unsigned long long
    T_STR,            // std::string tpy
    T_BOOL,           // bool type
    T_VECTOR_NUMERIC, // std::vector<unsigened long long>
    T_VECTOR_STR      // std::vector<std::string>
};

enum PARSEMETHOD {
    NOSPLIT,          // If the value is not splited into the vector
    SPLIT             // If the value is splited into the vector
};

// This specifies if a parameter will be followed by one extra argument.
enum EXTRAARGUMENT {
    NO,               // There is not extra argument
    OPTIONAL,         // It is possible to have one extra argument
    YES              // There is not one extra argument
};
class Parameter_base  {
    private:
        std::pair <std::string, std::string> commandLineArgument;
        std::string description;
        bool isSet;
        TYPE type;
        EXTRAARGUMENT  extraArgument;
        bool internal; // Does not have description

        // Only used for numeric argument
        unsigned long long rangeStart;
        unsigned long long rangeEnd;

        // Only used for std::string argument
        std::vector<std::string> validStrValues;

    public:
        Parameter_base();
        virtual ~Parameter_base();

        // Validate range
        bool validateNumericRange(unsigned long long var);

        // Validate str Valuesi if not empty
        bool validateStrRange(std::string var);

        std::string printCommandLineParameter();

        // Set members
        virtual void setCommandLineArgument(std::pair <std::string, std::string> var);
        virtual void setDescription(std::string var);
        virtual void setIsSet(bool var);
        virtual void setType(TYPE var);
        virtual void setExtraArgument(EXTRAARGUMENT var);
        virtual void setRangeStart(unsigned long long var);
        virtual void setRangeEnd(unsigned long long var);
        virtual void setRange(unsigned long long rangeStart, unsigned long long rangeEnd);
        virtual void addValidStrValue(std::string validStrValue);
        virtual void setInternal(bool var);
        // create one per type
        virtual void setValue(unsigned long long var) {}
        virtual void setValue(std::string var) {}
        // set and get parseMethod only for T_VECTOR
        virtual void setParseMethod(PARSEMETHOD var) {}

        // Get members
        virtual std::pair <std::string, std::string> getCommandLineArgument();
        virtual std::string getDescription();
        virtual bool getIsSet();
        virtual TYPE getType();
        virtual EXTRAARGUMENT getExtraArgument();
        virtual bool getInternal();
        virtual PARSEMETHOD getParseMethod();
        // create one per type
        virtual void getValue(unsigned long long &var) {}
        virtual void getValue(std::string &var) {}

};

template <typename T>
class Parameter : public Parameter_base {
    private:
        T value;

    public:
        Parameter()
        {
        }

        Parameter(T var)
        {
            value = var;
        }
        ~Parameter()
        {
        }
        Parameter(Parameter_base& p)
        {
        }

        T getValue()
        {
            T var;
            getValueInternal(var);
            return var;
        }

        void setValue(T var)
        {
            value = var;
            setIsSet(true);
        }

    private:
        void getValueInternal(T &var)
        {
            var = value;
        }
};

template <typename T>
class ParameterVector : public Parameter_base {
    private:
        std::vector<T> value;
        PARSEMETHOD parseMethod;

    public:
        ParameterVector()
        {
            parseMethod = NOSPLIT;
        }
        ParameterVector(T var)
        {
            parseMethod = NOSPLIT;
            value.clear();
            value.push_back(var);
        }
        ParameterVector(std::vector<T> var)
        {
            parseMethod = NOSPLIT;
            value.insert(value.begin(),var.begin(), var.end());
        }
        ~ParameterVector()
        {
            value.clear();
        }
        ParameterVector(Parameter_base& p)
        {
        }

        std::vector<T> getValue()
        {
            std::vector<T> var;
            getValueInternal(var);
            return var;
        }

        void setValue(T var)
        {
            if (!getIsSet()) {
                // In the case of is not set, remove default values.
                value.clear();
            }
            value.push_back(var);
            setIsSet(true);
        }

        void setParseMethod(PARSEMETHOD var)
        {
            parseMethod = var;
        }

        PARSEMETHOD getParseMethod()
        {
            return parseMethod;
        }

    private:
        void getValueInternal(std::vector<T> &var)
        {
            var = value;
        }
};


#endif // __PARAMETER_H__