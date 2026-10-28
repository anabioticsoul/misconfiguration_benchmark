package org.misconfigbench.ca21;

import javax.persistence.Entity;
import javax.persistence.Id;

@Entity
public class Widget {
    @Id
    private Long id;
    private String name;
    protected Widget() {}
}
