/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#ifndef RMLUI_CORE_DATACONTROLLERDEFAULT_H
#define RMLUI_CORE_DATACONTROLLERDEFAULT_H

#include "../Include/RmlUi/Platform.h"
#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/EventListener.h"
#include "../Include/RmlUi/DataVariable.h"
#include "DataController.h"

namespace Rml {

class Element;
class DataModel;
class DataExpression;
using DataExpressionPtr = std::unique_ptr<DataExpression>;


class DataControllerValue final : public DataController, private EventListener {
public:
    DataControllerValue(Element* element);
    ~DataControllerValue();

    bool Initialize(DataModel& model, Element* element, const std::string& expression, const std::string& modifier) override;

protected:
    void OnDetach(Element *) override {}
    void ProcessEvent(Event& event) override;
    void Release() override;

private:
    void SetValue(const Variant& new_value);

    DataAddress address;
};

struct DataControllerEventListener;

class DataControllerEvent final : public DataController {
public:
    DataControllerEvent(Element* element);
    ~DataControllerEvent();

    bool Initialize(DataModel& model, Element* element, const std::string& expression, const std::string& modifier) override;

protected:
    void Release() override;

private:
    std::unique_ptr<DataControllerEventListener> listener;
};

} // namespace Rml
#endif
