/* Copyright 2011-2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * The representation of an IMAP parenthesized list.
 *
 * See [[http://tools.ietf.org/html/rfc3501#section-4.4]]
 */

public class Geary.Imap.ListParameter : Geary.Imap.Parameter {
    /**
     * The maximum length a literal parameter may be to be auto-converted to a StringParameter
     * in the StringParameter getters.
     */
    public const int MAX_STRING_LITERAL_LENGTH = 4096;
    
    /**
     * Returns the number of {@link Parameter}s held in this {@link ListParameter}.
     */
    public int size {
        get {
            return list.size;
        }
    }
    
    /**
     * Returns null if no parent (top-level list).
     *
     * In a fully-formed set of {@link Parameter}s, this means this {@link ListParameter} is
     * probably a {@link RootParameters}.
     */
    public weak ListParameter? parent { get; private set; default = null; }
    
    private Gee.List<Parameter> list = new Gee.ArrayList<Parameter>();
    
    /**
     * Creates an empty ListParameter with no parent.
     */
    public ListParameter() {
    }
    
    ~ListParameter() {
        // Drop back links because, although it's a weak ref, sometimes ListParameters are temporarily
        // made and current Vala doesn't reset weak refs
        foreach (Parameter param in list) {
            ListParameter? listp = param as ListParameter;
            if (listp != null) {
                assert(listp.parent == this);
                
                listp.parent = null;
            }
        }
    }
    
    /**
     * Adds the {@link Parameter} to the end of the {@link ListParameter}.
     *
     * If the Parameter is itself a ListParameter, it's {@link parent} will be set to this
     * ListParameter.
     *
     * The same {@link Parameter} can't be added more than once to the same {@link ListParameter}.
     * There are no other restrictions, however.
     *
     * @return true if added.
     */
    public bool add(Parameter param) {
        // if adding a ListParameter, set its parent
        ListParameter? listp = param as ListParameter;
        if (listp != null) {
            if (listp.parent != null)
                listp.parent.list.remove(listp);
            
            listp.parent = this;
        }
        
        return list.add(param);
    }
    
    /**
     * Adds all the {@link Parameter}s to the end of the {@link ListParameter}.
     *
     * If any Parameter is itself a ListParameter, it's {@link parent} will be set to this
     * ListParameter.
     *
     * The same {@link Parameter} can't be added more than once to the same {@link ListParameter}.
     * There are no other restrictions, however.
     *
     * @return number of Parameters added.
     */
    public int add_all(Gee.Collection<Parameter> params) {
        int count = 0;
        foreach (Parameter param in params)
            count += add(param) ? 1 : 0;
        
        return count;
    }
    
    /**
     * Appends the {@link ListParameter} to the end of this ListParameter.
     *
     * The difference between this call and {@link add} is that add() will simply insert the
     * {@link Parameter} to the tail of the list.  Thus, add(ListParameter) will add a child list
     * inside this list, i.e. add(ListParameter("three")):
     *
     * (one two (three))
     *
     * append(ListParameter("three")) adds each element of the ListParameter to this one, not
     * creating a child:
     *
     * (one two three)
     *
     * Thus, each element of the list is moved ("adopted") by this list, and the supplied list
     * returns empty.  This is slightly different than {@link adopt_children}, which preserves the
     * list structure.
     *
     * @return Number of added elements.  append() will not abort if an element fails to add.
     */
    public int append(ListParameter listp) {
        // snap the child list off the supplied ListParameter so it's wiped clean
        Gee.List<Parameter> to_append = listp.list;
        listp.list = new Gee.ArrayList<Parameter>();
        
        int count = 0;
        foreach (Parameter param in to_append) {
            if (add(param))
                count++;
        }
        
        return count;
    }
    
    /**
     * Clears the {@link ListParameter} of all its children.
     *
     * This also clears (sets to null) the parents of all {@link ListParamater} children.
     */
    public void clear() {
        // sever ties to ListParameter children
        foreach (Parameter param in list) {
            ListParameter? listp = param as ListParameter;
            if (listp != null)
                listp.parent = null;
        }
        
        list.clear();
    }
    
    //
    // Parameter retrieval
    //
    
    /**
     * Returns the {@link Parameter} at the index in the list, null if index is out of range.
     *
     * TODO: This call can cause memory leaks when used with the "as" operator until the following
     * Vala bug is fixed (probably in version 0.19.1).
     * [[https://bugzilla.gnome.org/show_bug.cgi?id=695671]]
     */
    public new Parameter? get(int index) {
        return ((index >= 0) && (index < list.size)) ? list.get(index) : null;
    }
    
    /**
     * Returns the Parameter at the index.  Throws an ImapError.TYPE_ERROR if the index is out of
     * range.
     *
     * TODO: This call can cause memory leaks when used with the "as" operator until the following
     * Vala bug is fixed (probably in version 0.19.1).
     * [[https://bugzilla.gnome.org/show_bug.cgi?id=695671]]
     */
    public Parameter get_required(int index) throws ImapError {
        if ((index < 0) || (index >= list.size))
            throw new ImapError.TYPE_ERROR("No parameter at index %d", index);
        
        Parameter? param = list.get(index);
        if (param == null)
            throw new ImapError.TYPE_ERROR("No parameter at index %d", index);
        
        return param;
    }
    
    /**
     * Returns {@link Parameter} at index if in range and of Type type, otherwise throws an
     * {@link ImapError.TYPE_ERROR}.
     *
     * type must be of type Parameter.
     */
    public Parameter get_as(int index, Type type) throws ImapError {
        if (!type.is_a(typeof(Parameter)))
            throw new ImapError.TYPE_ERROR("Attempting to cast non-Parameter at index %d", index);
        
        Parameter param = get_required(index);
        if (!param.get_type().is_a(type)) {
            throw new ImapError.TYPE_ERROR("Parameter %d is not of type %s (is %s)", index,
                type.name(), param.get_type().name());
        }
        
        return param;
    }
    
    /**
     * Like {@link get_as}, but returns null if the {@link Parameter} at index is a
     * {@link NilParameter}.
     *
     * type must be of type Parameter.
     */
    public Parameter? get_as_nullable(int index, Type type) throws ImapError {
        if (!type.is_a(typeof(Parameter)))
            throw new ImapError.TYPE_ERROR("Attempting to cast non-Parameter at index %d", index);
        
        Parameter param = get_required(index);
        if (param is NilParameter)
            return null;
        
        // Because Deserializer doesn't produce NilParameters, check manually if this Parameter
        // can legally be NIL according to IMAP grammer.
        StringParameter? stringp = param as StringParameter;
        if (stringp != null && NilParameter.is_nil(stringp))
            return null;
        
        if (!param.get_type().is_a(type)) {
            throw new ImapError.TYPE_ERROR("Parameter %d is not of type %s (is %s)", index,
                type.name(), param.get_type().name());
        }
        
        return param;
    }
    
    /**
     * Like {@link get}, but returns null if {@link Parameter} at index is not of the specified type.
     *
     * type must be of type Parameter.
     */
    public Parameter? get_if(int index, Type type) {
        if (!type.is_a(typeof(Parameter)))
            return null;
        
        Parameter? param = get(index);
        if (param == null || !param.get_type().is_a(type))
            return null;
        
        return param;
    }
    
    //
    // String retrieval
    //
    
    /**
     * Returns a {@link StringParameter} only if the {@link Parameter} at index is a StringParameter.
     *
     * Compare to {@link get_as_nullable_string}.
     */
    public StringParameter? get_if_string(int index) {
        return (StringParameter?) get_if(index, typeof(StringParameter));
    }
    
    /**
     * Returns a {@link StringParameter} for the value at the index only if the {@link Parameter}
     * is a StringParameter or a {@link LiteralParameter} with a length less than or equal to
     * {@link MAX_STRING_LITERAL_LENGTH}.
     *
     * Because literal data is being coerced into a StringParameter, the result may not be suitable
     * for transmission as-is.
     *
     * @see get_as_nullable_string
     * @throws ImapError.TYPE_ERROR if no StringParameter at index or the literal is longer than
     * MAX_STRING_LITERAL_LENGTH.
     */
    public StringParameter get_as_string(int index) throws ImapError {
        Parameter param = get_required(index);
        
        StringParameter? stringp = param as StringParameter;
        if (stringp != null)
            return stringp;
        
        LiteralParameter? literalp = param as LiteralParameter;
        if (literalp != null && literalp.get_size() <= MAX_STRING_LITERAL_LENGTH)
            return literalp.coerce_to_string_parameter();
        
        throw new ImapError.TYPE_ERROR("Parameter %d not of type string or literal (is %s)", index,
            param.get_type().name());
    }
    
    /**
     * Returns a {@link StringParameter} for the value at the index only if the {@link Parameter}
     * is a StringParameter or a {@link LiteralParameter} with a length less than or equal to
     * {@link MAX_STRING_LITERAL_LENGTH}.
     *
     * Because literal data is being coerced into a StringParameter, the result may not be suitable
     * for transmission as-is.
     *
     * @return null if no StringParameter or LiteralParameter at index.
     * @see get_as_string
     * @throws ImapError.TYPE_ERROR if literal is longer than MAX_STRING_LITERAL_LENGTH.
     */
    public StringParameter? get_as_nullable_string(int index) throws ImapError {
        Parameter? param = get_as_nullable(index, typeof(Parameter));
        if (param == null)
            return null;
        
        StringParameter? stringp = param as StringParameter;
        if (stringp != null)
            return stringp;
        
        LiteralParameter? literalp = param as LiteralParameter;
        if (literalp != null && literalp.get_size() <= MAX_STRING_LITERAL_LENGTH)
            return literalp.coerce_to_string_parameter();
        
        throw new ImapError.TYPE_ERROR("Parameter %d not of type string or literal (is %s)", index,
            param.get_type().name());
    }
    
    /**
     * Much like get_as_nullable_string() but returns an empty StringParameter (rather than null)
     * if the parameter at index is a NilParameter.
     */
    public StringParameter get_as_empty_string(int index) throws ImapError {
        StringParameter? stringp = get_as_nullable_string(index);
        
        return stringp ?? StringParameter.get_best_for("");
    }
    
    //
    // List retrieval
    //
    
    /**
     * Returns a {@link ListParameter} at index.
     *
     * @see get_as
     */
    public ListParameter get_as_list(int index) throws ImapError {
        return (ListParameter) get_as(index, typeof(ListParameter));
    }
    
    /**
     * Returns a {@link ListParameter} at index, null if NIL.
     *
     * @see get_as_nullable
     */
    public ListParameter? get_as_nullable_list(int index) throws ImapError {
        return (ListParameter?) get_as_nullable(index, typeof(ListParameter));
    }
    
    /**
     * Returns [@link ListParameter} at index, an empty list if NIL.
     *
     * If an empty ListParameter has to be manufactured in place of a NIL parameter, its parent
     * will be null.
     */
    public ListParameter get_as_empty_list(int index) throws ImapError {
        ListParameter? param = get_as_nullable_list(index);
        
        return param ?? new ListParameter();
    }
    
    /**
     * Returns a {@link ListParameter} at index, null if not a list.
     *
     * @see get_if
     */
    public ListParameter? get_if_list(int index) {
        return (ListParameter?) get_if(index, typeof(ListParameter));
    }
    
    //
    // Literal retrieval
    //
    
    /**
     * Returns a {@link LiteralParameter} at index.
     *
     * @see get_as
     */
    public LiteralParameter get_as_literal(int index) throws ImapError {
        return (LiteralParameter) get_as(index, typeof(LiteralParameter));
    }
    
    /**
     * Returns a {@link LiteralParameter} at index, null if NIL.
     *
     * @see get_as_nullable
     */
    public LiteralParameter? get_as_nullable_literal(int index) throws ImapError {
        return (LiteralParameter?) get_as_nullable(index, typeof(LiteralParameter));
    }
    
    /**
     * Returns a {@link LiteralParameter} at index, null if not a list.
     *
     * @see get_if
     */
    public LiteralParameter? get_if_literal(int index) {
        return (LiteralParameter?) get_if(index, typeof(LiteralParameter));
    }
    
    /**
     * Returns [@link LiteralParameter} at index, an empty list if NIL.
     */
    public LiteralParameter get_as_empty_literal(int index) throws ImapError {
        LiteralParameter? param = get_as_nullable_literal(index);
        
        return param ?? new LiteralParameter(Geary.Memory.EmptyBuffer.instance);
    }
    
    /**
     * Returns a {@link Memory.Buffer} for the {@link Parameter} at position index.
     *
     * Only converts {@link StringParameter} and {@link LiteralParameter}.  All other types return
     * null.
     */
    public Memory.Buffer? get_as_nullable_buffer(int index) throws ImapError {
        LiteralParameter? literalp = get_if_literal(index);
        if (literalp != null)
            return literalp.get_buffer();
        
        StringParameter? stringp = get_if_string(index);
        if (stringp != null)
            return new Memory.StringBuffer(stringp.value);
        
        return null;
    }
    
    /**
     * Returns a {@link Memory.Buffer} for the {@link Parameter} at position index.
     *
     * Only converts {@link StringParameter} and {@link LiteralParameter}.  All other types return
     * as an empty buffer.
     */
    public Memory.Buffer get_as_empty_buffer(int index) throws ImapError {
        return get_as_nullable_buffer(index) ?? Memory.EmptyBuffer.instance;
    }
    
    /**
     * Returns a read-only List of {@link Parameter}s.
     */
    public Gee.List<Parameter> get_all() {
        return list.read_only_view;
    }
    
    /**
     * Returns the replaced Paramater.  Throws ImapError.TYPE_ERROR if no Parameter exists at the
     * index.
     */
    public Parameter replace(int index, Parameter parameter) throws ImapError {
        if (list.size <= index)
            throw new ImapError.TYPE_ERROR("No parameter at index %d", index);
        
        Parameter old = list[index];
        list[index] = parameter;
        
        // add parent to new Parameter if a list
        ListParameter? listp = parameter as ListParameter;
        if (listp != null) {
            if (listp.parent != null)
                listp.parent.list.remove(listp);
            
            listp.parent = this;
        }
        
        // clear parent of old Parameter if a list
        listp = old as ListParameter;
        if (listp != null)
            listp.parent = null;
        
        return old;
    }
    
    /**
     * Moves all child parameters from the supplied list into this list, clearing this list first.
     *
     * The supplied list will be "stripped" of its children.  This ListParameter is cleared prior
     * to adopting the new children.
     */
    public void adopt_children(ListParameter src) {
        clear();
        
        Gee.List<Parameter> src_children = new Gee.ArrayList<Parameter>();
        src_children.add_all(src.list);
        src.clear();
        
        add_all(src_children);
    }
    
    protected string stringize_list() {
        StringBuilder builder = new StringBuilder();
        
        int length = list.size;
        for (int ctr = 0; ctr < length; ctr++) {
            builder.append(list[ctr].to_string());
            if (ctr < (length - 1))
                builder.append_c(' ');
        }
        
        return builder.str;
    }
    
    /**
     * {@inheritDoc}
     */
    public override string to_string() {
        return "(%s)".printf(stringize_list());
    }
    
    protected void serialize_list(Serializer ser, Tag tag) throws Error {
        int length = list.size;
        for (int ctr = 0; ctr < length; ctr++) {
            list[ctr].serialize(ser, tag);
            if (ctr < (length - 1))
                ser.push_space();
        }
    }
    
    /**
     * {@inheritDoc}
     */
    public override void serialize(Serializer ser, Tag tag) throws Error {
        ser.push_ascii('(');
        serialize_list(ser, tag);
        ser.push_ascii(')');
    }
}

