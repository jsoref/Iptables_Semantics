(*  Title:      CIDRSplit.thy
    Authors:    Julius Michaelis, Cornelius Diekmann
*)
theory CIDR_Split
imports IPAddr
        PrefixMatch
        Hs_Compat
begin

section\<open>CIDR Split Motivation (Example for IPv4)\<close>
  text\<open>When talking about ranges of IP addresses, we can make the ranges explicit by listing them.\<close>
context
begin
  private lemma "map (of_nat \<circ> nat) [1 .. 4] = ([1, 2, 3, 4]:: 32 word list)" by eval
  private definition ipv4addr_upto :: "32 word \<Rightarrow> 32 word \<Rightarrow> 32 word list" where
    "ipv4addr_upto i j \<equiv> map (of_nat \<circ> nat) [int (unat i) .. int (unat j)]"
  private lemma ipv4addr_upto: "set (ipv4addr_upto i j) = {i .. j}"
    proof -
    have helpX:"\<And>f (i::nat) (j::nat). (f \<circ> nat) ` {int i..int j} = f ` {i .. j}"
      apply(intro set_eqI)
      apply(safe)
       apply(force)
      by (metis Set_Interval.transfer_nat_int_set_functions(2) image_comp image_eqI)
    {   fix xa :: int
        assume a1: "int (unat i) \<le> xa \<and> xa \<le> int (unat j)"
        then have f2: "int (nat xa) = xa"
          by force
        then have "unat (of_int xa::32 word) = nat xa"
          using a1 by (metis (full_types) le_unat_uoi nat_int nat_mono of_int_of_nat_eq)
        then have "i \<le> of_int xa" and "of_int xa \<le> j"
          using f2 a1 by (metis (no_types) uint_nat word_le_def)+
    } note hlp=this
    show ?thesis
      unfolding ipv4addr_upto_def
      apply(intro set_eqI)
      apply(simp)
      apply(safe)
        apply(simp_all)
        using hlp apply blast
       using hlp apply blast
      apply(simp add: helpX)
      by (metis atLeastAtMost_iff image_eqI word_le_nat_alt word_unat.Rep_inverse)
    qed

  text\<open>The function @{const ipv4addr_upto} gives back a list of all the ips in the list.
        This list can be pretty huge! In the following, we will use CIDR notation (e.g. 192.168.0.0/24)
        to describe the list more compactly.\<close>
end



section\<open>CIDR Split\<close>

context
begin
(*pfxes needs a dummy parameter. The first parameter is a dummy that we have the 'a::len0 type and
  can refer to its length.*)
private definition pfxes :: "'a::len0 itself \<Rightarrow> nat list" where
  "pfxes _ = map nat [0..int(len_of TYPE ('a))]"

lemma "pfxes TYPE(32) = map nat [0 .. 32]" by eval

text\<open>somebody likes Haskell here\<close>
private definition "const x \<equiv> \<lambda>y. x"

text\<open>The idiom @{term "find (const True)"} is basically a safe version of @{const List.hd}\<close>
private lemma "find (const True) cfs = (if cfs = [] then None else Some (hd cfs))"
  by(induction cfs) (simp_all split: split_if_asm add: const_def)
private lemma find_const_True_hlp: "find (const True) x = (case x of [] \<Rightarrow> None | (a#as) \<Rightarrow> Some a)"
  by(cases x; simp add: const_def)
private lemma find_const_True: "find (const True) l = None \<longleftrightarrow> l = []"
  by(cases l, simp_all add: const_def) 
private lemma hd_find_const: "l \<noteq> [] \<Longrightarrow> hd l = the (find (const True) l)"
proof -
	assume "l \<noteq> []" then obtain a ls where [simp]: "l = a # ls" by(cases l) blast+
	then show "hd l = the (find (const True) l)" by(simp add: const_def)
qed


text\<open>Split off one prefix\<close>
private definition wordinterval_CIDR_split1
  :: "'a::len wordinterval \<Rightarrow> 'a prefix_match option \<times> 'a wordinterval" where
  "wordinterval_CIDR_split1 r \<equiv> (
   let ma = wordinterval_lowest_element r in
   case ma of None \<Rightarrow> (None, r) |
              Some a \<Rightarrow> let cs = (map (\<lambda>s. PrefixMatch a s) (pfxes TYPE('a)));
                            cfs = filter (\<lambda>s. valid_prefix s \<and> wordinterval_subset (prefix_to_wordinterval s) r) cs;
                            (* anything that is a subset should also be a valid prefix. but try proving that.*)
                            mc = find (const True) cfs
                        in 
                        (case mc of None \<Rightarrow> (None, r) |
                                  Some m \<Rightarrow> (mc, wordinterval_setminus r (prefix_to_wordinterval m))))"


private lemma wordinterval_CIDR_split1_innard_helper: fixes a::"'a::len word"
  shows "wordinterval_lowest_element r = Some a \<Longrightarrow> 
  [s \<leftarrow> map (\<lambda>s. PrefixMatch a s) (pfxes TYPE('a)).
                  valid_prefix s \<and>
                  wordinterval_to_set (prefix_to_wordinterval s) \<subseteq> wordinterval_to_set r] \<noteq> []"
proof -
  assume a: "wordinterval_lowest_element r = Some a"
  have b: "(a,len_of(TYPE('a))) \<in> set (map (Pair a) (pfxes TYPE('a)))"
    unfolding pfxes_def
    unfolding set_map set_upto
    using Set.image_iff atLeastAtMost_iff int_eq_iff order_refl by metis (*400ms*)
  have c: "valid_prefix (PrefixMatch a (len_of(TYPE('a))))" by(simp add: valid_prefix_def pfxm_mask_def)
  have "wordinterval_to_set (prefix_to_wordinterval (PrefixMatch a (len_of(TYPE('a))))) = {a}"
    unfolding prefix_to_wordinterval_def pfxm_mask_def by simp
  moreover have "a \<in> wordinterval_to_set r"
    using a wordinterval_lowest_element_set_eq wordinterval_lowest_none_empty
    by (metis is_lowest_element_def option.distinct(1))
  ultimately have d:
    "wordinterval_to_set (prefix_to_wordinterval (PrefixMatch a (len_of TYPE('a)))) \<subseteq> wordinterval_to_set r"
    by simp
  show ?thesis
    unfolding arg_cong_Not[OF set_empty[symmetric]]
    apply simp
    using b c d by auto
qed
private lemma r_split1_not_none: fixes r:: "'a::len wordinterval"
  shows "\<not> wordinterval_empty r \<Longrightarrow> fst (wordinterval_CIDR_split1 r) \<noteq> None"
  unfolding wordinterval_CIDR_split1_def Let_def
  apply(cases "wordinterval_lowest_element r")
   apply(simp add: wordinterval_lowest_none_empty; fail)
  apply(simp)
  apply(rename_tac a)
  apply(case_tac "find (const True) [s\<leftarrow>map (\<lambda>s. PrefixMatch a s) (pfxes TYPE('a)). valid_prefix s \<and> wordinterval_subset (prefix_to_wordinterval s) r]")
   apply(simp add: find_const_True wordinterval_CIDR_split1_innard_helper; fail)
  apply(simp)
done
private lemma find_in: "Some a = find f s \<Longrightarrow> a \<in> {x \<in> set s. f x}"
  by (metis CollectI find_Some_iff nth_mem)
private theorem wordinterval_CIDR_split1_preserve: fixes r:: "'a::len wordinterval"
  shows "(Some s, u) = wordinterval_CIDR_split1 r \<Longrightarrow> wordinterval_eq (wordinterval_union (prefix_to_wordinterval s) u) r"
proof(unfold wordinterval_eq_set_eq)
  assume as: "(Some s, u) = wordinterval_CIDR_split1 r"
  have nn: "wordinterval_lowest_element r \<noteq> None"
    using as unfolding wordinterval_CIDR_split1_def Let_def
    by (metis (erased, lifting) Pair_inject option.distinct(2) option.simps(4))
  then obtain a where a:  "Some a = (wordinterval_lowest_element r)" unfolding not_None_eq by force
  then have cpf: "find (const True) [s\<leftarrow>map (\<lambda>s. PrefixMatch a s) (pfxes TYPE('a)). valid_prefix s \<and> wordinterval_subset (prefix_to_wordinterval s) r] \<noteq> None" (is "?cpf \<noteq> None")
    unfolding arg_cong_Not[OF find_const_True]
    using wordinterval_CIDR_split1_innard_helper
    by force (*TODO: tune*)
  then obtain m where m: "m = the ?cpf" by blast
  have s_def: "wordinterval_CIDR_split1 r =
    (find (const True) [s\<leftarrow>map (\<lambda>s. PrefixMatch a s) (pfxes TYPE('a)). valid_prefix s \<and> wordinterval_subset (prefix_to_wordinterval s) r], wordinterval_setminus r (prefix_to_wordinterval m))"
    unfolding m wordinterval_CIDR_split1_def Let_def using cpf
    unfolding a[symmetric]
    unfolding option.simps(5)
    using option.collapse
    by force
  have "u = wordinterval_setminus r (prefix_to_wordinterval s)"
    using as unfolding s_def using m by (metis (no_types, lifting) Pair_inject Some_to_the)
  moreover have "wordinterval_subset (prefix_to_wordinterval s) r"
    using as unfolding s_def
    apply(rule Pair_inject)
    apply(unfold const_def)
    apply(drule find_in)
    apply(unfold set_filter)
    by blast
  ultimately show "wordinterval_to_set (wordinterval_union (prefix_to_wordinterval s) u) = wordinterval_to_set r" by auto
qed

definition wordinterval_CIDR_split1_2
  :: "'a::len wordinterval \<Rightarrow> 'a prefix_match option \<times> 'a wordinterval" where
  "wordinterval_CIDR_split1_2 r \<equiv> (
   let ma = wordinterval_lowest_element r in
   case ma of None \<Rightarrow> (None, r) |
              Some a \<Rightarrow> let cs = (map (\<lambda>s. PrefixMatch a s) (pfxes TYPE('a)));
                            ms = (filter (\<lambda>s. valid_prefix s \<and> wordinterval_subset (prefix_to_wordinterval s) r) cs) in
                            (Some (hd ms), wordinterval_setminus r (prefix_to_wordinterval (hd ms))))"



lemma wordinterval_CIDR_split1_2_eq[code]: "wordinterval_CIDR_split1 s = wordinterval_CIDR_split1_2 s"
	apply(simp add: wordinterval_CIDR_split1_2_def wordinterval_CIDR_split1_def split: option.splits)
	apply(clarify)
	apply(frule hd_find_const[OF wordinterval_CIDR_split1_innard_helper])
	apply(simp split: option.splits add: Let_def)
	apply(rule ccontr)
	apply(unfold not_ex not_Some_eq find_const_True)
	apply(drule wordinterval_CIDR_split1_innard_helper)
	apply simp
done

private lemma wordinterval_CIDR_split1_some_r_ne:
  "(Some s, u) = wordinterval_CIDR_split1 r \<Longrightarrow> \<not> wordinterval_empty r"
proof(rule ccontr, goal_cases)
  case 1
  have "wordinterval_lowest_element r = None" unfolding wordinterval_lowest_none_empty using 1(2) unfolding not_not .
  then have "wordinterval_CIDR_split1 r = (None, r)" unfolding wordinterval_CIDR_split1_def Let_def by simp
  then show False using 1(1) by simp
qed

private lemma wordinterval_CIDR_split1_distinct: fixes r:: "'a::len wordinterval"
  shows "(Some s, u) = wordinterval_CIDR_split1 r \<Longrightarrow>
           wordinterval_empty (wordinterval_intersection (prefix_to_wordinterval s) u)"
proof(goal_cases)
  case 1
  have nn: "wordinterval_lowest_element r \<noteq> None"
    using wordinterval_CIDR_split1_some_r_ne[OF 1, unfolded wordinterval_lowest_none_empty[symmetric]] .
  obtain a where ad: "Some a = wordinterval_lowest_element r" using nn by force
  {
    fix rr :: "'a::len prefix_match \<Rightarrow> 'b option \<times> 'a wordinterval"
    have "(case find (const True) [s\<leftarrow>map (PrefixMatch a) (pfxes TYPE('a)). valid_prefix s \<and> wordinterval_subset (prefix_to_wordinterval s) r] of None \<Rightarrow> (None, r)
                 | Some m \<Rightarrow> rr m) = rr (the (find (const True) [s\<leftarrow>map (PrefixMatch a) (pfxes TYPE('a)). valid_prefix s \<and> wordinterval_subset (prefix_to_wordinterval s) r]))"
                  using wordinterval_CIDR_split1_innard_helper[OF ad[symmetric]] find_const_True by fastforce
  } note uf2 = this
  from 1 have "u = wordinterval_setminus r (prefix_to_wordinterval s)"
    unfolding wordinterval_CIDR_split1_def Let_def
    unfolding ad[symmetric] option.cases
    unfolding uf2
    unfolding prod.inject (*TODO: tune*)
    by (metis option.sel)
  then show ?thesis by simp
qed
private lemma wordinterval_CIDR_split1_distinct2: fixes r:: "'a::len wordinterval"
  shows "wordinterval_CIDR_split1 r = (Some s, u) \<Longrightarrow>
          wordinterval_empty (wordinterval_intersection (prefix_to_wordinterval s) u)"
by(rule wordinterval_CIDR_split1_distinct[where r = r]) simp

function wordinterval_CIDR_split_prefixmatch :: "'a::len wordinterval \<Rightarrow> 'a prefix_match list"where
  "wordinterval_CIDR_split_prefixmatch rs = (
      if
        \<not> wordinterval_empty rs
      then case wordinterval_CIDR_split1 rs
                      of (Some s, u) \<Rightarrow> s # wordinterval_CIDR_split_prefixmatch u
                      |   _ \<Rightarrow> []
      else
        []
      )"
  by clarsimp+

termination wordinterval_CIDR_split_prefixmatch
proof(relation "measure (card \<circ> wordinterval_to_set)", rule wf_measure, unfold in_measure comp_def, goal_cases)
  note vernichter = wordinterval_empty_set_eq wordinterval_intersection_set_eq wordinterval_union_set_eq wordinterval_eq_set_eq
  case (1 rs x y x2)
  note some = 1(2)[unfolded 1(3)]
  from prefix_never_empty have "\<not> wordinterval_empty (prefix_to_wordinterval x2)" .
  thus ?case
    unfolding vernichter
    unfolding wordinterval_CIDR_split1_preserve[OF some, unfolded vernichter, symmetric]
    unfolding card_Un_disjoint[OF finite finite wordinterval_CIDR_split1_distinct[OF some, unfolded vernichter]]
    by (metis add.commute add_left_cancel card_0_eq finite linorder_neqE_nat monoid_add_class.add.right_neutral not_add_less1)
qed

private lemma unfold_rsplit_case:
  assumes su: "(Some s, u) = wordinterval_CIDR_split1 rs"
  shows "(case wordinterval_CIDR_split1 rs of (None, u) \<Rightarrow> []
                                            | (Some s, u) \<Rightarrow> s # wordinterval_CIDR_split_prefixmatch u) = s # wordinterval_CIDR_split_prefixmatch u"
using su by (metis option.simps(5) split_conv)

private lemma wordinterval_CIDR_split_prefixmatch_union: "\<Union>set (map wordinterval_to_set (map prefix_to_wordinterval (wordinterval_CIDR_split_prefixmatch r))) = wordinterval_to_set r"
proof(induction r rule: wordinterval_CIDR_split_prefixmatch.induct, 
  subst wordinterval_CIDR_split_prefixmatch.simps, case_tac "wordinterval_empty rs", goal_cases)
  case 1
  show ?case using 1(2) by (simp)
next
  case (2 rs)
  obtain u s where su: "(Some s, u) = wordinterval_CIDR_split1 rs" using r_split1_not_none[OF 2(2)] by (metis option.collapse surjective_pairing)
  from 2(1)[OF 2(2) su, of s] have mIH: "\<Union>set (map wordinterval_to_set (map prefix_to_wordinterval (wordinterval_CIDR_split_prefixmatch u))) = wordinterval_to_set u" by presburger
  from wordinterval_CIDR_split1_preserve[OF su, unfolded wordinterval_eq_set_eq wordinterval_union_def] have
    helper1: "wordinterval_to_set (prefix_to_wordinterval s) \<union> wordinterval_to_set u = wordinterval_to_set rs"
    unfolding wordinterval_union_set_eq by simp
  show ?case
    unfolding eqTrueI[OF 2(2)]
    unfolding if_True
    unfolding unfold_rsplit_case[OF su]
    unfolding list.map
    using mIH helper1
    by (metis Sup_insert list.set(2))
qed

lemma "wordinterval_CIDR_split_prefixmatch
          (RangeUnion (WordInterval (0x40000000) 0x5FEFBBCC) (WordInterval 0x5FEEBB1C 0x7FFFFFFF))
       = [PrefixMatch (0x40000000::32 word) 2]" by eval
lemma "length (wordinterval_CIDR_split_prefixmatch (WordInterval 0 (0xFFFFFFFE::32 word))) = 32" by eval


declare wordinterval_CIDR_split_prefixmatch.simps[simp del]

corollary wordinterval_CIDR_split_prefixmatch:
  "(\<Union>x\<in>set (wordinterval_CIDR_split_prefixmatch r). prefix_to_wordset x) = wordinterval_to_set r"
  proof -
  have prefix_to_wordinterval_set_eq_fun: "prefix_to_wordset = (wordinterval_to_set \<circ> prefix_to_wordinterval)"
    by(simp add: prefix_to_wordinterval_set_eq fun_eq_iff)
  have "\<Union>(prefix_to_wordset ` set (wordinterval_CIDR_split_prefixmatch r)) =
        UNION (set (map prefix_to_wordinterval (wordinterval_CIDR_split_prefixmatch r))) wordinterval_to_set"
    by(simp add: prefix_to_wordinterval_set_eq_fun)
  thus ?thesis
   using wordinterval_CIDR_split_prefixmatch_union by simp
qed


lemma wordinterval_CIDR_split_prefixmatch_all_valid_Ball: fixes r:: "'a::len wordinterval"
  shows "Ball (set (wordinterval_CIDR_split_prefixmatch r)) valid_prefix"
apply(induction r rule: wordinterval_CIDR_split_prefixmatch.induct)
proof(subst wordinterval_CIDR_split_prefixmatch.simps, rename_tac rs, case_tac "wordinterval_empty rs", goal_cases)
  case 1 thus ?case
    by(simp only: not_True_eq_False if_False Ball_def set_simps empty_iff) clarify
next
  case (2 rs)
  obtain u s where su: "(Some s, u) = wordinterval_CIDR_split1 rs" using r_split1_not_none[OF 2(2)] by (metis option.collapse surjective_pairing)
  note mIH = 2(1)[OF 2(2) su refl]
  have vpfx: "valid_prefix s"
  proof -
    obtain a where a: "wordinterval_lowest_element rs = Some a"
      using 2(2)[unfolded arg_cong_Not[OF wordinterval_lowest_none_empty, symmetric]]
      by force
    obtain m where m: "find (const True) [s\<leftarrow>map (PrefixMatch a) (pfxes TYPE('a)). valid_prefix s \<and> wordinterval_subset (prefix_to_wordinterval s) rs] = Some m"
      using wordinterval_CIDR_split1_innard_helper[OF a, unfolded arg_cong_Not[OF find_const_True, symmetric]]
      by force
    note su[unfolded wordinterval_CIDR_split1_def Let_def]
    then have "(Some s, u) =
          (case find (const True) [s\<leftarrow>map (PrefixMatch a) (pfxes TYPE('a)). valid_prefix s \<and> wordinterval_subset (prefix_to_wordinterval s) rs] of None \<Rightarrow> (None, rs)
           | Some m \<Rightarrow> (find (const True) [s\<leftarrow>map (PrefixMatch a) (pfxes TYPE('a)). valid_prefix s \<and> wordinterval_subset (prefix_to_wordinterval s) rs], wordinterval_setminus rs (prefix_to_wordinterval m)))"
       unfolding a by simp
    then have "(Some s, u) =
          (Some m, wordinterval_setminus rs (prefix_to_wordinterval m))"
       unfolding m by simp
    moreover
    note find_in[OF m[symmetric]]
    ultimately
    show "valid_prefix s" by simp
  qed
  show ?case
    unfolding eqTrueI[OF 2(2)]
    unfolding if_True
    unfolding unfold_rsplit_case[OF su]
    unfolding list.set
    using mIH vpfx
    by blast
qed

private lemma wordinterval_CIDR_split_prefixmatch_all_valid_less_Ball_hlp:
	"x \<in> set [s\<leftarrow>map (PrefixMatch x2) (pfxes TYPE('a::len0)) . valid_prefix s \<and> wordinterval_to_set (prefix_to_wordinterval s) \<subseteq> wordinterval_to_set rs] \<Longrightarrow> pfxm_length x \<le> len_of TYPE('a)"
by(clarsimp simp: pfxes_def) presburger

(*TODO: delete*)
private lemma cons_set_intro:
  "lst = x # xs \<Longrightarrow> x \<in> set lst"
  by fastforce


lemma wordinterval_CIDR_split_prefixmatch_all_valid_less_Ball: 
  fixes r:: "'a::len wordinterval"
  shows "Ball (set (wordinterval_CIDR_split_prefixmatch r)) (\<lambda>e. pfxm_length e \<le> len_of TYPE('a))"
	apply(subst Ball_def)
	apply(clarify)
	apply(induction rule: wordinterval_CIDR_split_prefixmatch.induct)
	apply(subst(asm)(2) wordinterval_CIDR_split_prefixmatch.simps)
	apply(simp only: split: if_splits) (* wooooo, simplifier bug! (try without the only) *)
	prefer 2
	 apply(simp;fail)
	apply(clarsimp)
	apply(elim disjE)
	 prefer 2
	 apply(simp;fail)
	apply(simp add: wordinterval_CIDR_split1_def Let_def find_const_True_hlp split: option.splits list.splits)
	apply(drule cons_set_intro)
	apply(drule wordinterval_CIDR_split_prefixmatch_all_valid_less_Ball_hlp)
	apply blast
done

text\<open>Since @{const wordinterval_CIDR_split_prefixmatch} only returns valid prefixes, we can safely convert it to CIDR lists\<close>
(* actually, just valid_prefix doesn't mean that the prefix length is sane. Fortunately, we also have wordinterval_CIDR_split_prefixmatch_all_valid_less_Ball *)
lemma "valid_prefix (PrefixMatch (0::16 word) 20)" by(simp add: valid_prefix_def)

definition cidr_split :: "'i::len wordinterval \<Rightarrow> ('i word \<times> nat) list" where
  "cidr_split rs \<equiv> map prefix_match_to_CIDR (wordinterval_CIDR_split_prefixmatch rs)"
                                        
text\<open>Versions for @{const ipset_from_cidr}\<close>
corollary cidr_split_prefix: 
  fixes r :: "'i::len wordinterval"
  shows "(\<Union>x\<in>set (cidr_split r). uncurry ipset_from_cidr x) = wordinterval_to_set r"
  proof -
  --"without valid prefix assumption"
  have prefix_to_wordset_subset_ipset_from_cidr_helper:
    "(\<Union>x\<in>X. prefix_to_wordset x) \<subseteq> (\<Union>x\<in>X. ipset_from_cidr (pfxm_prefix x) (pfxm_length x))"
    for X :: "'i prefix_match set"
    apply(rule)
    using prefix_to_wordset_subset_ipset_from_cidr by fastforce

  have ipset_from_cidr_subseteq_prefix_to_wordset_helper:
    "\<forall> x \<in> X. valid_prefix x \<Longrightarrow> (\<Union>x\<in>X. ipset_from_cidr (pfxm_prefix x) (pfxm_length x)) \<subseteq> (\<Union>x\<in>X. prefix_to_wordset x)"
    for X :: "'i prefix_match set"
    using prefix_to_wordset_ipset_from_cidr by auto

  show ?thesis
    unfolding wordinterval_CIDR_split_prefixmatch[symmetric] cidr_split_def
    apply(simp add: prefix_match_to_CIDR_def2)
    apply(rule)
     apply(simp add: ipset_from_cidr_subseteq_prefix_to_wordset_helper wordinterval_CIDR_split_prefixmatch_all_valid_Ball)
    apply(simp add: prefix_to_wordset_subset_ipset_from_cidr_helper)
    done
qed
corollary cidr_split_prefix_single: 
  fixes start :: "'i::len word"
  shows "(\<Union>x\<in>set (cidr_split (iprange_interval (start, end))). uncurry ipset_from_cidr x) = {start..end}"
  unfolding wordinterval_to_set.simps[symmetric]
  using cidr_split_prefix iprange_interval.simps by metis

private lemma interval_in_splitD: "xa \<in> foo \<Longrightarrow> prefix_to_wordset xa \<subseteq> \<Union>(prefix_to_wordset ` foo)" by auto

lemma wordinterval_CIDR_split_prefixmatch_distinct: "distinct (wordinterval_CIDR_split_prefixmatch a)"
	apply(induction rule: wordinterval_CIDR_split_prefixmatch.induct)
	apply(subst wordinterval_CIDR_split_prefixmatch.simps)
	apply(clarsimp split: prod.splits option.splits)
	apply(drule_tac xa = x2a in interval_in_splitD)
	apply(simp add: wordinterval_CIDR_split_prefixmatch)
	apply(drule wordinterval_CIDR_split1_distinct[OF sym])
	apply(simp add: prefix_to_wordinterval_set_eq[symmetric])
using prefix_never_empty by fastforce

lemma CIDR_splits_disjunct: "a \<in> set (wordinterval_CIDR_split_prefixmatch i) \<Longrightarrow>
  b \<in> set (wordinterval_CIDR_split_prefixmatch i) \<Longrightarrow> a \<noteq> b \<Longrightarrow>
  prefix_to_wordset a \<inter> prefix_to_wordset b = {}"
apply(induction rule: wordinterval_CIDR_split_prefixmatch.induct)
apply(subst(asm)(4) wordinterval_CIDR_split_prefixmatch.simps)
apply(subst(asm)(3) wordinterval_CIDR_split_prefixmatch.simps)
apply(clarsimp simp only: set_simps not_False_eq_True split: if_splits prod.splits option.splits)
apply(rename_tac rem x2b ne)
apply(case_tac "b = ne"; case_tac "a = ne")
   apply(simp;fail)
  prefer 3
  apply(simp;fail)
 (*apply(clarsimp, metis (full_types) Int_commute disjoint_subset2 interval_in_splitD prefix_to_wordinterval_set_eq wordinterval_CIDR_split1_distinct wordinterval_CIDR_split_prefixmatch wordinterval_empty_set_eq wordinterval_intersection_set_eq)+*)
 apply(subgoal_tac "prefix_to_wordset b \<inter> wordinterval_to_set rem = {}")
  apply(simp add: wordinterval_CIDR_split_prefixmatch[symmetric])
  apply(clarsimp)
  apply blast
 apply(intro wordinterval_CIDR_split1_distinct2[unfolded wordinterval_empty_set_eq wordinterval_intersection_set_eq prefix_to_wordinterval_set_eq]; fast)
apply(subgoal_tac "prefix_to_wordset a \<inter> wordinterval_to_set rem = {}")
 apply(simp add: wordinterval_CIDR_split_prefixmatch[symmetric])
 apply(clarsimp)
 apply blast
apply(intro wordinterval_CIDR_split1_distinct2[unfolded wordinterval_empty_set_eq wordinterval_intersection_set_eq prefix_to_wordinterval_set_eq]; fast)
done

lemma wordinterval_CIDR_split_existential:
	"x \<in> wordinterval_to_set w \<Longrightarrow> \<exists>s. s \<in> set (wordinterval_CIDR_split_prefixmatch w) \<and> x \<in> prefix_to_wordset s"
using wordinterval_CIDR_split_prefixmatch[symmetric] by fastforce

lemma cidrsplit_no_overlaps: "\<lbrakk>
        x \<in> set (wordinterval_CIDR_split_prefixmatch wi);
        xa \<in> set (wordinterval_CIDR_split_prefixmatch wi); 
        pt && ~~ pfxm_mask x = pfxm_prefix x;
        pt && ~~ pfxm_mask xa = pfxm_prefix xa
        \<rbrakk>
       \<Longrightarrow> x = xa"
proof(rule ccontr, goal_cases)
	case 1
	hence "prefix_match_semantics x pt" "prefix_match_semantics xa pt" unfolding prefix_match_semantics_def by (simp_all add: word_bw_comms(1))
	moreover have "valid_prefix x" "valid_prefix xa" using 1(1-2) wordinterval_CIDR_split_prefixmatch_all_valid_Ball by blast+
	ultimately have "pt \<in> prefix_to_wordset x" "pt \<in> prefix_to_wordset xa"
	  using prefix_match_semantics_wordset by blast+
	with CIDR_splits_disjunct[OF 1(1,2) 1(5)] show False by blast
qed

end



end
